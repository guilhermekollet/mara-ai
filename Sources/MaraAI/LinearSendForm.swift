import SwiftUI

/// Review step before creating the issue: shows the destination and lets you pick the assignee and due date.
struct LinearSendForm: View {
    @EnvironmentObject private var model: CaptionModel
    let action: MeetingAction
    @Binding var isPresented: Bool
    @State private var assigneeID = ""
    @State private var hasDueDate = false
    @State private var title = ""
    @State private var priority = 0
    @State private var dueDate = Date()

    private static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                LinearLogo(size: 13)
                Text("Nova issue em \(model.linearTeamName)")
                    .font(.system(size: 13, weight: .semibold))
            }
            TextField("Título", text: $title, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            VStack(alignment: .leading, spacing: 4) {
                Text("Prioridade")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                Picker("Prioridade", selection: $priority) {
                    ForEach(DemandPriority.all, id: \.self) { value in
                        Text(DemandPriority.title(value)).tag(value)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Responsável")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                Picker("Responsável", selection: $assigneeID) {
                    Text("Sem responsável").tag("")
                    ForEach(model.linearMembers) { member in
                        Text(member.name).tag(member.id)
                    }
                }
                .labelsHidden()
                if assigneeID.isEmpty && !action.owner.isEmpty {
                    Text("Citado na reunião: \(action.owner). Vai na descrição da issue.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.paper.opacity(0.45))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Definir prazo", isOn: $hasDueDate)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 11.5))
                if hasDueDate {
                    DatePicker("Prazo", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                } else if !action.due.isEmpty {
                    Text("Citado na reunião: \(action.due). Vai na descrição da issue.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.paper.opacity(0.45))
                }
            }

            HStack {
                Button("Cancelar") { isPresented = false }
                    .buttonStyle(PillButtonStyle(prominent: false))
                Spacer()
                Button("Criar issue") {
                    model.sendToLinear(
                        action.id,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        priority: priority,
                        assigneeID: assigneeID.isEmpty ? nil : assigneeID,
                        dueDate: hasDueDate ? Self.isoDay.string(from: dueDate) : nil
                    )
                    isPresented = false
                }
                .buttonStyle(PillButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(Theme.ink)
        .foregroundStyle(Theme.paper)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            title = action.title
            priority = action.priority
            assigneeID = model.suggestedAssignee(for: action.owner) ?? ""
            if let saved = action.dueDate, let date = Self.isoDay.date(from: saved) {
                dueDate = date
                hasDueDate = true
            }
        }
    }
}
