//
//  ContentView.swift
//  taskmanagement
//
//  Created by 坂本龍征 on 2025/08/28.
//

import SwiftUI

struct Todo: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var title: String
    var details: String
    var estimatedHours: Int
    var estimatedMinutes: Int
    var dueDate: Date
    var createdAt: Date
    var isDone: Bool = false
    var isToday: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        details: String,
        estimatedHours: Int,
        estimatedMinutes: Int,
        dueDate: Date,
        createdAt: Date = Date(),
        isDone: Bool = false,
        isToday: Bool = false
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.estimatedHours = estimatedHours
        self.estimatedMinutes = estimatedMinutes
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.isDone = isDone
        self.isToday = isToday
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, details, estimatedHours, estimatedMinutes, dueDate, createdAt, isDone, isToday
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
        estimatedHours = try container.decodeIfPresent(Int.self, forKey: .estimatedHours) ?? 0
        estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes) ?? 0
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate) ?? Date()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        isToday = try container.decodeIfPresent(Bool.self, forKey: .isToday) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(details, forKey: .details)
        try container.encode(estimatedHours, forKey: .estimatedHours)
        try container.encode(estimatedMinutes, forKey: .estimatedMinutes)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isDone, forKey: .isDone)
        try container.encode(isToday, forKey: .isToday)
    }
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
            let matchesFilter: Bool = {
                switch filter {
                case .all:
                    return !t.isToday
                case .today:
                    return t.isToday
                }
            }()
            return matchesFilter && !t.isDone
        }
    }
    private var filteredDoneIndices: [Int] {
        store.todos.indices.filter { i in
            let t = store.todos[i]
            let matchesFilter: Bool = {
                switch filter {
                case .all:
                    return !t.isToday
                case .today:
                    return t.isToday
                }
            }()
            return matchesFilter && t.isDone
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
                            NavigationLink {
                                TodoDetailView(todo: $store.todos[i])
                            } label: {
                                TodoRow(todo: $store.todos[i])
                            }
                            // 右スワイプ：今日に移動（すべての一覧のみ）
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if filter == .all {
                                    Button {
                                        withAnimation(.easeInOut) { store.todos[i].isToday = true }
                                    } label: {
                                        Label("今日", systemImage: "sun.max")
                                    }
                                    .tint(.orange)
                                }
                            }
                            // 左スワイプ：削除 or すべてに戻す
                            .swipeActions(edge: .trailing) {
                                if filter == .today {
                                    Button {
                                        withAnimation(.easeInOut) { store.todos[i].isToday = false }
                                    } label: {
                                        Label("すべてに戻す", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.gray)
                                } else {
                                    Button(role: .destructive) {
                                        withAnimation { _ = store.todos.remove(at: i) }
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    // 完了セクション（存在する場合のみ）
                    if !filteredDoneIndices.isEmpty {
                        Section(filter == .today ? "今日の完了" : "完了") {
                            ForEach(filteredDoneIndices, id: \.self) { i in
                                NavigationLink {
                                    TodoDetailView(todo: $store.todos[i])
                                } label: {
                                    TodoRow(todo: $store.todos[i])
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    if filter == .all {
                                        Button {
                                            withAnimation(.easeInOut) { store.todos[i].isToday = true }
                                        } label: {
                                            Label("今日", systemImage: "sun.max")
                                        }
                                        .tint(.orange)
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    if filter == .today {
                                        Button {
                                            withAnimation(.easeInOut) { store.todos[i].isToday = false }
                                        } label: {
                                            Label("すべてに戻す", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.gray)
                                    } else {
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
            }
            .listStyle(.insetGrouped)
            .navigationTitle("タスク")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
                AddTodoView(defaultIsToday: filter == .today) { todo in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        store.todos.append(todo)
                    }
                }
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
    @Binding var todo: Todo
    @State private var showEdit = false

    private var estimatedTimeDescription: String {
        let hours = todo.estimatedHours
        let minutes = todo.estimatedMinutes
        switch (hours, minutes) {
        case (0, 0):
            return "0分"
        case (_, 0):
            return "\(hours)時間"
        case (0, _):
            return "\(minutes)分"
        default:
            return "\(hours)時間 \(minutes)分"
        }
    }

    private var detailsText: String {
        let trimmed = todo.details.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未入力" : trimmed
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DetailField(title: "タイトル") {
                    Text(todo.title)
                        .font(.body)
                }
                DetailField(title: "内容") {
                    Text(detailsText)
                        .foregroundStyle(detailsText == "未入力" ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                }
                DetailField(title: "見積もり時間") {
                    Text(estimatedTimeDescription)
                }
                DetailField(title: "期日") {
                    Text(Self.dateFormatter.string(from: todo.dueDate))
                }
                DetailField(title: "作成日時") {
                    Text(Self.dateTimeFormatter.string(from: todo.createdAt))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("タスク詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("編集") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                EditTodoView(todo: $todo)
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct DetailField<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
            )
        }
    }
}

struct EditTodoView: View {
    @Binding var todo: Todo
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var hasLoadedInitialValues = false

    var body: some View {
        Form {
            Section("タイトル") {
                TextField("タスク名を入力", text: $title)
                    .autocorrectionDisabled()
            }
        }
        .navigationTitle("タスクを編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { saveChanges() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            guard !hasLoadedInitialValues else { return }
            title = todo.title
            hasLoadedInitialValues = true
        }
    }

    private func saveChanges() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.easeInOut) {
            todo.title = trimmed
        }
        dismiss()
    }
}

struct AddTodoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var details: String = ""
    @State private var estimatedHours: Int = 1
    @State private var estimatedMinutes: Int = 0
    @State private var dueDate: Date = Date()
    let defaultIsToday: Bool
    var onSave: (Todo) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル") {
                    TextField("例: 牛乳を買う", text: $title)
                        .autocorrectionDisabled()
                }
                Section("内容") {
                    TextEditor(text: $details)
                        .frame(minHeight: 120)
            }
            Section("見積もり時間") {
                HStack {
                    Picker("時間", selection: $estimatedHours) {
                        ForEach(0..<13) { hour in
                            Text("\(hour)時間").tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity, maxHeight: 140)
                    .clipped()
                    .labelsHidden()

                    Picker("分", selection: $estimatedMinutes) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text("\(minute)分").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity, maxHeight: 140)
                    .clipped()
                    .labelsHidden()
                }
            }
                Section("期日") {
                    DatePicker("期日", selection: $dueDate, displayedComponents: [.date])
                        .datePickerStyle(.wheel)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }
            }
            .navigationTitle("新規タスク")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                dueDate = Date()
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTodo = Todo(
            title: trimmedTitle,
            details: trimmedDetails,
            estimatedHours: estimatedHours,
            estimatedMinutes: estimatedMinutes,
            dueDate: dueDate,
            createdAt: Date(),
            isToday: defaultIsToday
        )
        onSave(newTodo)
        dismiss()
    }
}

#Preview {
    ContentView()
}
