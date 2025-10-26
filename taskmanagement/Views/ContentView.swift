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
    private let seededKey = "hasSeededTutorialTodos"
    
    init() {
        load()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Todo].self, from: data) {
            self.todos = decoded
        } else {
            self.todos = []
        }

        if defaults.bool(forKey: seededKey) == false {
            seedTutorialTodos()
            defaults.set(true, forKey: seededKey)
        }
    }

    private func seedTutorialTodos() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let upcoming = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let allTutorial = Todo(
            title: "右にスワイプすると今日やることのタスクに移動",
            details: "タスクを右方向にスワイプして今日のタスクへ移動してみましょう。",
            estimatedHours: 0,
            estimatedMinutes: 0,
            dueDate: upcoming,
            createdAt: Date(),
            isToday: false
        )

        let todayTutorial = Todo(
            title: "左にスワイプするとすべてのタスクに移動",
            details: "今日のタスクから左にスワイプして元の一覧へ戻してみましょう。",
            estimatedHours: 0,
            estimatedMinutes: 0,
            dueDate: upcoming,
            createdAt: Date(),
            isToday: true
        )

        todos.insert(contentsOf: [allTutorial, todayTutorial], at: 0)
    }
}

struct ContentView: View {
    @StateObject private var store = TodoStore()
    @State private var newTodo = ""
    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var filter: ListFilter = .all
    @AppStorage("hasSeenTaskOnboarding") private var hasSeenOnboarding = false
    @State private var isOnboardingVisible = false

    // インデックスを使って Binding を保ったままフィルタするヘルパー
    private var filteredPendingIndices: [Int] {
        let indices = store.todos.indices.filter { i in
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
        return indices.sorted { lhs, rhs in
            store.todos[lhs].dueDate < store.todos[rhs].dueDate
        }
    }
    private var filteredDoneIndices: [Int] {
        let indices = store.todos.indices.filter { i in
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
        return indices.sorted { lhs, rhs in
            store.todos[lhs].dueDate < store.todos[rhs].dueDate
        }
    }
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    if filteredPendingIndices.isEmpty && filteredDoneIndices.isEmpty {
                        EmptyStateView(title: filter == .today ? "今日のタスクはありません" : "はじめてのタスクを追加しよう")
                    } else {
                        Section(filter == .today ? "今日の予定" : "予定") {
                            ForEach(filteredPendingIndices, id: \.self) { i in
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

                if isOnboardingVisible {
                    OnboardingOverlay {
                        hasSeenOnboarding = true
                        withAnimation(.easeInOut) { isOnboardingVisible = false }
                    }
                }
            }
            .navigationTitle(filter == .all ? "すべて" : "今日")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("設定")
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    FilterButton(
                        filter: .all,
                        activeIcon: "tray.full.fill",
                        inactiveIcon: "tray.full",
                        accessibilityLabel: "すべて",
                        current: $filter
                    )
                    Spacer(minLength: 32)
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                    .accessibilityLabel("新規タスク")
                    Spacer(minLength: 32)
                    FilterButton(
                        filter: .today,
                        activeIcon: "sun.max.fill",
                        inactiveIcon: "sun.max",
                        accessibilityLabel: "今日",
                        current: $filter
                    )
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddTodoView(defaultIsToday: filter == .today) { todo in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        store.todos.append(todo)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .onAppear {
            if !hasSeenOnboarding {
                withAnimation(.easeInOut) { isOnboardingVisible = true }
            }
        }
    }
}


struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section("その他") {
                    Button {
                        if let url = URL(string: "https://rules-privacy-9a6dd.web.app/") {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Text("プライバシーポリシー / 利用規約")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct TodoRow: View {
    @Binding var todo: Todo

    private var estimatedTimeText: String {
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

    private var dueDateDescription: String {
        TodoDetailView.dateFormatter.string(from: todo.dueDate)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isDone ? Color.green : Color.gray)
                    .imageScale(.large)
                    .onTapGesture { withAnimation(.easeInOut) { todo.isDone.toggle() } }
                Spacer(minLength: 0)
            }
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 8) {
                Text(todo.title)
                    .font(.headline)
                    .strikethrough(todo.isDone)
                    .foregroundStyle(todo.isDone ? .secondary : .primary)
                    .animation(.easeInOut(duration: 0.2), value: todo.isDone)

                HStack(alignment: .center, spacing: 12) {
                    Label {
                        Text(estimatedTimeText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Label {
                        Text(dueDateDescription)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.subheadline)
                    .foregroundStyle(todo.dueDate < Calendar.current.startOfDay(for: Date()) ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    fileprivate static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    fileprivate static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct OnboardingOverlay: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Text("タスクの操作を覚えよう")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 18) {
                    OnboardingPoint(icon: "arrow.right.circle", text: "右へスワイプしてタスクを「今日」に移動")
                    OnboardingPoint(icon: "arrow.uturn.backward.circle", text: "左へスワイプして元に戻す／削除する")
                    OnboardingPoint(icon: "square.and.pencil", text: "タスクをタップして詳細を確認・編集する")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )

                Button {
                    onDismiss()
                } label: {
                    Text("はじめる")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                        )
                }
            }
            .padding(32)
        }
    }
}

private struct OnboardingPoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .font(.title3)
            Text(text)
                .foregroundStyle(.primary)
                .font(.body)
        }
    }
}

private struct FilterButton: View {
    let filter: ListFilter
    let activeIcon: String
    let inactiveIcon: String
    let accessibilityLabel: String
    @Binding var current: ListFilter

    var isActive: Bool { current == filter }

    var body: some View {
        Button {
            current = filter
        } label: {
            Image(systemName: isActive ? activeIcon : inactiveIcon)
                .font(.title2)
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .padding(10)
                .background(
                    Circle()
                        .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("\(accessibilityLabel)のタスクを表示")
    }
}

fileprivate struct DetailField<Content: View>: View {
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

private struct TodoFormState: Equatable {
    static let hourOptions = Array(0...12)
    static let minuteOptions = [0, 15, 30, 45]

    var title: String = ""
    var details: String = ""
    var estimatedHours: Int = 1
    var estimatedMinutes: Int = 0
    var dueDate: Date = Date()

    init() {}

    init(todo: Todo) {
        self.title = todo.title
        self.details = todo.details
        self.estimatedHours = Self.hourOptions.contains(todo.estimatedHours) ? todo.estimatedHours : min(max(todo.estimatedHours, 0), Self.hourOptions.last ?? 12)
        self.estimatedMinutes = Self.minuteOptions.contains(todo.estimatedMinutes) ? todo.estimatedMinutes : Self.minuteOptions.first ?? 0
        self.dueDate = todo.dueDate
    }
}

private struct TodoFormView: View {
    @Binding var state: TodoFormState

    var body: some View {
        Form {
            Section("タイトル") {
                TextField("例: 牛乳を買う", text: $state.title)
                    .autocorrectionDisabled()
            }
            Section("内容") {
                TextEditor(text: $state.details)
                    .frame(minHeight: 120)
            }
            Section("見積もり時間") {
                HStack {
                    Picker("時間", selection: $state.estimatedHours) {
                        ForEach(TodoFormState.hourOptions, id: \.self) { hour in
                            Text("\(hour)時間").tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity, maxHeight: 140)
                    .clipped()
                    .labelsHidden()

                    Picker("分", selection: $state.estimatedMinutes) {
                        ForEach(TodoFormState.minuteOptions, id: \.self) { minute in
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
                DatePicker("期日", selection: $state.dueDate, displayedComponents: [.date])
                    .datePickerStyle(.wheel)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
            }
        }
    }
}

struct EditTodoView: View {
    @Binding var todo: Todo
    @Environment(\.dismiss) private var dismiss
    @State private var formState = TodoFormState()
    @State private var hasLoadedInitialValues = false

    var body: some View {
        TodoFormView(state: $formState)
        .navigationTitle("タスクを編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { saveChanges() }
                    .disabled(formState.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            guard !hasLoadedInitialValues else { return }
            formState = TodoFormState(todo: todo)
            hasLoadedInitialValues = true
        }
    }

    private func saveChanges() {
        let trimmed = formState.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.easeInOut) {
            todo.title = trimmed
            todo.details = formState.details.trimmingCharacters(in: .whitespacesAndNewlines)
            todo.estimatedHours = formState.estimatedHours
            todo.estimatedMinutes = formState.estimatedMinutes
            todo.dueDate = formState.dueDate
        }
        dismiss()
    }
}

struct AddTodoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var formState = TodoFormState()
    let defaultIsToday: Bool
    var onSave: (Todo) -> Void

    var body: some View {
        NavigationStack {
            TodoFormView(state: $formState)
            .navigationTitle("新規タスク")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        save()
                    }
                    .disabled(formState.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                formState = TodoFormState()
            }
        }
    }

    private func save() {
        let trimmedTitle = formState.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedDetails = formState.details.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTodo = Todo(
            title: trimmedTitle,
            details: trimmedDetails,
            estimatedHours: formState.estimatedHours,
            estimatedMinutes: formState.estimatedMinutes,
            dueDate: formState.dueDate,
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
