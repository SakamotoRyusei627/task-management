//
//  ContentView.swift
//  taskmanagement
//
//  Created by 坂本龍征 on 2025/08/28.
//

import SwiftUI

struct Todo: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var isDone: Bool = false
    var isToday: Bool = false
}

private enum ListFilter: String, CaseIterable, Identifiable, Codable {
    case all = "すべて"
    case today = "今日"
    var id: String { rawValue }
}

class TodoStore: ObservableObject {
    @Published var todos: [Todo] = [] {
        didSet {
            save()
        }
    }
    private let key = "todos_key"
    
    init() {
        load()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Todo].self, from: data) {
            self.todos = decoded
        }
        
    }
}

struct ContentView: View {
    @StateObject private var store = TodoStore()
    @State private var newTodo = ""
    @State private var showAddSheet = false
    @State private var filter: ListFilter = .all

    // インデックスを使って Binding を保ったままフィルタするヘルパー
    private var filteredPendingIndices: [Int] {
        store.todos.indices.filter { i in
            let t = store.todos[i]
            let passesFilter = (filter == .all) || t.isToday
            return passesFilter && !t.isDone
        }
    }
    private var filteredDoneIndices: [Int] {
        store.todos.indices.filter { i in
            let t = store.todos[i]
            let passesFilter = (filter == .all) || t.isToday
            return passesFilter && t.isDone
        }
    }
    var body: some View {
        NavigationStack {
            List {
                if filteredPendingIndices.isEmpty && filteredDoneIndices.isEmpty {
                    EmptyStateView(title: filter == .today ? "今日のタスクはありません" : "はじめてのタスクを追加しよう")
                } else {
                    // 予定（未完了）
                    Section(filter == .today ? "今日の予定" : "予定") {
                        ForEach(filteredPendingIndices, id: \.self) { i in
                            NavigationLink(value: store.todos[i]) {
                                TodoRow(todo: $store.todos[i])
                            }
                            // 右スワイプ：完了
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    withAnimation(.easeInOut) { store.todos[i].isDone.toggle() }
                                } label: {
                                    Label("完了", systemImage: "checkmark")
                                }
                                .tint(.green)
                                // 今日に入れる/外す
                                if !store.todos[i].isToday {
                                    Button {
                                        withAnimation(.easeInOut) { store.todos[i].isToday = true }
                                    } label: {
                                        Label("今日", systemImage: "sun.max")
                                    }
                                    .tint(.orange)
                                } else {
                                    Button {
                                        withAnimation(.easeInOut) { store.todos[i].isToday = false }
                                    } label: {
                                        Label("今日から外す", systemImage: "sun.min")
                                    }
                                    .tint(.gray)
                                }
                            }
                            // 左スワイプ：削除
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation { _ = store.todos.remove(at: i) }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                        .onMove { from, to in
                            withAnimation { store.todos.move(fromOffsets: from, toOffset: to) }
                        }
                    }
                    // 完了セクション（存在する場合のみ）
                    if !filteredDoneIndices.isEmpty {
                        Section(filter == .today ? "今日の完了" : "完了") {
                            ForEach(filteredDoneIndices, id: \.self) { i in
                                NavigationLink(value: store.todos[i]) {
                                    TodoRow(todo: $store.todos[i])
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        withAnimation(.easeInOut) { store.todos[i].isDone.toggle() }
                                    } label: {
                                        Label("未完了に戻す", systemImage: "arrow.uturn.left")
                                    }
                                    .tint(.orange)
                                    if store.todos[i].isToday {
                                        Button {
                                            withAnimation(.easeInOut) { store.todos[i].isToday = false }
                                        } label: {
                                            Label("今日から外す", systemImage: "sun.min")
                                        }
                                        .tint(.gray)
                                    } else {
                                        Button {
                                            withAnimation(.easeInOut) { store.todos[i].isToday = true }
                                        } label: {
                                            Label("今日", systemImage: "sun.max")
                                        }
                                        .tint(.orange)
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        withAnimation { _ = store.todos.remove(at: i) }
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("タスク")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .principal) {
                    Picker("リスト", selection: $filter) {
                        ForEach(ListFilter.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("新規タスク")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddTodoView { title in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        store.todos.append(Todo(title: title, isToday: filter == .today))
                    }
                }
            }
            .navigationDestination(for: Todo.self) { todo in
                TodoDetailView(todo: todo)
            }
        }
    }
}


struct TodoRow: View {
    @Binding var todo: Todo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(todo.isDone ? Color.green : Color.gray)
                .imageScale(.large)
                .onTapGesture { withAnimation(.easeInOut) { todo.isDone.toggle() } }

            Text(todo.title)
                .strikethrough(todo.isDone)
                .foregroundStyle(todo.isDone ? .secondary : .primary)
                .animation(.easeInOut(duration: 0.2), value: todo.isDone)
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

struct TodoDetailView: View {
    let todo: Todo
    var body: some View {
        VStack(spacing: 20) {
            Text("Todoの詳細")
                .font(.headline)
            Text(todo.title)
                .font(.largeTitle)
            Text(todo.isDone ? "✅ 完了済み" : "⏳ 未完了")
                .font(.title2)
        }
        .padding()
    }
}

struct AddTodoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    var onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル") {
                    TextField("例: 牛乳を買う", text: $title)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("新規タスク")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
