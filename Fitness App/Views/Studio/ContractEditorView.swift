import SwiftUI
import SwiftData

struct ContractEditorView: View {
    @Bindable var gym: Gym
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteDialog = false

    /// Bound straight to the model so the editor never holds a stale copy.
    private var draft: MembershipContract? {
        get { gym.contract }
        nonmutating set { gym.contract = newValue }
    }

    /// Non-optional binding for the form fields. Unlike `Binding(optionalBinding)`
    /// it can't crash when the contract is removed while the fields are still on
    /// screen: it falls back to the last value and ignores writes after removal.
    private func contractBinding(fallback: MembershipContract) -> Binding<MembershipContract> {
        Binding(
            get: { gym.contract ?? fallback },
            set: { newValue in
                guard gym.contract != nil else { return }
                gym.contract = newValue
            }
        )
    }

    var body: some View {
        Form {
            if let current = gym.contract {
                fields(contractBinding(fallback: current))
            } else {
                Section {
                    Button("Vertrag anlegen", systemImage: "plus") {
                        draft = MembershipContract(startDate: Calendar.current.startOfDay(for: .now))
                    }
                } footer: {
                    Text("Die App rechnet aus, bis wann du spätestens kündigen musst, und erinnert dich rechtzeitig.")
                }
            }
        }
        .navigationTitle("Mitgliedschaft")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: gym.contractData) {
            ContractReminder.reschedule(for: gym)
        }
        .onChange(of: draft?.reminderEnabled) { _, enabled in
            if enabled == true {
                Task {
                    await RestTimer.requestAuthorization()
                    ContractReminder.reschedule(for: gym)
                }
            }
        }
        .task {
            if draft?.reminderEnabled == true { await RestTimer.requestAuthorization() }
        }
        .confirmationDialog("Vertrag entfernen?", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("Vertrag entfernen", role: .destructive, action: removeContract)
        }
    }

    private func removeContract() {
        draft = nil
        ContractReminder.cancel(for: gym)
        try? modelContext.save()
    }

    @ViewBuilder
    private func fields(_ contract: Binding<MembershipContract>) -> some View {
        Section("Vertrag") {
            TextField("Mitgliedsnummer", text: contract.memberNumber)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            TextField("Monatsbeitrag", value: contract.monthlyFee, format: .currency(code: "EUR"))
                .keyboardType(.decimalPad)
            DatePicker("Vertragsbeginn", selection: contract.startDate, displayedComponents: .date)
        }

        Section {
            Stepper(value: contract.minimumTermMonths, in: 0...48) {
                LabeledContent("Mindestlaufzeit", value: Format.count(contract.wrappedValue.minimumTermMonths, "Monat", "Monate"))
            }
            Stepper(value: contract.renewalMonths, in: 1...24) {
                LabeledContent("Danach Verlängerung um", value: Format.count(contract.wrappedValue.renewalMonths, "Monat", "Monate"))
            }
            Stepper(value: contract.noticeValue, in: 0...24) {
                LabeledContent("Kündigungsfrist", value: "\(contract.wrappedValue.noticeValue) \(contract.wrappedValue.noticeUnit.label(contract.wrappedValue.noticeValue))")
            }
            Picker("Einheit der Frist", selection: contract.noticeUnit) {
                ForEach(NoticeUnit.allCases) { unit in
                    Text(unit.pluralLabel).tag(unit)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Laufzeit & Kündigung")
        } footer: {
            Text("Verträge ab März 2022 verlängern sich nach der Mindestlaufzeit meist nur noch monatsweise und sind mit einem Monat Frist kündbar. Schau im Zweifel in deinen Vertrag.")
        }

        Section("Erinnerung") {
            Toggle("Vor Kündigungsfrist erinnern", isOn: contract.reminderEnabled)
            if contract.wrappedValue.reminderEnabled {
                Stepper(value: contract.reminderLeadDays, in: 1...90) {
                    LabeledContent("Vorlauf", value: Format.count(contract.wrappedValue.reminderLeadDays, "Tag", "Tage"))
                }
            }
        }

        Section("Berechnet") {
            let value = contract.wrappedValue
            if let minEnd = value.minimumTermEnd() {
                LabeledContent("Mindestlaufzeit bis", value: minEnd.formatted(date: .long, time: .omitted))
            }
            if let next = value.nextCancellation() {
                LabeledContent("Spätestens kündigen bis", value: next.deadline.formatted(date: .long, time: .omitted))
                LabeledContent("Vertrag endet dann am", value: next.termEnd.formatted(date: .long, time: .omitted))
            }
            if value.reminderEnabled {
                if let reminder = ContractReminder.reminderDate(for: value) {
                    LabeledContent("Erinnerung am", value: reminder.formatted(date: .long, time: .shortened))
                } else {
                    Text("Vorlauf bereits erreicht – keine Erinnerung mehr für diese Frist.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Section {
            Button("Vertrag entfernen", role: .destructive) { showDeleteDialog = true }
        }
    }
}
