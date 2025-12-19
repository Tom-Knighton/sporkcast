//
//  HomeInvitePage.swift
//  Settings
//
//  Created by Tom Knighton on 26/10/2025.
//

import SwiftUI
import Design
import CloudKit
import Dependencies
import Persistence

public struct HomeInvitePage: View {
    
    @Environment(\.homeServices) private var homes
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    let ownerName: String
    let ownerEmail: String?
    var invite: CKShare.Metadata?
    
    @State private var state: JoinState = .start
    @State private var showError: Bool = false
    @State private var showSameHomeError: Bool = false
    @State private var showInHomeError: Bool = false
    
    @Dependency(\.defaultDatabase) private var db
    @Dependency(\.defaultSyncEngine) private var syncEngine
    
    enum JoinState: Equatable {
        case start, pending, success, fail
    }
    
    public init(for invite: CKShare.Metadata) {
        self.invite = invite
        title = (invite.rootRecord?[CKShare.SystemFieldKey.title] as? String) ?? "Home"
        ownerName = invite.ownerIdentity.nameComponents?.formatted(.name(style: .long)) ?? "Your Friend"
        ownerEmail = invite.ownerIdentity.lookupInfo?.emailAddress
    }
    
    public init(demoTitle: String, demoOwnerName: String, demoEmail: String?) {
        @Dependency(\.context) var context

        if context != .preview {
            fatalError("The Demo version of HomeInvitePage is not intended to be used in production.")
        }
        
        self.title = demoTitle
        self.ownerEmail = demoEmail
        self.ownerName = demoOwnerName
        
        self.invite = nil
    }
    
    public var body: some View {
        ZStack {
            Color.layer1.ignoresSafeArea()
            VStack {
                Text("Join \(Text("\(ownerName)'s").bold()) home: \(Text(title).bold())?")
                    .font(.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                SporkSpinnerView()
                    .frame(maxWidth: 400, maxHeight: 400)
                
                if self.state == .start || self.state == .fail {
                    Spacer()
                    ForEach(disclaimers(), id: \.self) { disclaimer in
                        Text(disclaimer)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .padding(.vertical, 2)
                            .font(.callout)
                    }
                    
                    Spacer()
                    
                    Button(action: { self.accept() }) {
                        Text("Accept and Join")
                            .padding(8)
                            .bold()
                    }
                    .buttonSizing(.flexible)
                    .tint(.blue)
                    .buttonStyle(.glassProminent)
                    Spacer().frame(height: 16)
                    Button(role: .close, action: {})
                }
                
                if self.state == .pending {
                    Spacer()
                    ProgressView("Syncing...")
                        .progressViewStyle(.circular)
                        .scaleEffect(1.75)
                        .font(.system(size: 8))
                }
                
                if self.state == .success {
                    Spacer()
                    Text("Success!")
                        .bold()
                    Button(action: { self.dismiss() }) {
                        Text("Continue")
                            .padding(8)
                            .bold()
                    }
                    .buttonSizing(.flexible)
                    .tint(.blue)
                    .buttonStyle(.glassProminent)
                }
               
            }
            .scenePadding()
            .fontDesign(.rounded)

        }
        .onChange(of: self.state, initial: true) { _, newValue in
            if newValue == .fail {
                self.showError = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button(role: .close) {}
        } message: {
            Text("Something went wrong joining this home. Please try again or ask for a new invite.")
        }
        .alert("Good News!", isPresented: $showSameHomeError) {
            Button(role: .close) { self.dismiss() }
        } message: {
            Text("You're already in this home - no action needed!")
        }
        .alert("Warning", isPresented: $showInHomeError) {
            Button(role: .cancel) { self.dismiss() }
            Button(role: .destructive) { self.accept(overrideInHome: true) } label: { Text("Continue") }
            
        } message: {
            Text("You're already part of a different home. If you accept this invite - you'll lose access to that home and any recipes shared exclusively to that home.")
        }

    }
    
    public func disclaimers() -> [String] {
        return ["Your current and future recipes and mealplans will be synced with the home's", "You can leave at any time."]
    }
    
    private func extractId(from id: CKRecord.ID) -> UUID? {
        let parsed = id.recordName
            .replacingOccurrences(of: "share-", with: "")
            .replacingOccurrences(of: ":Homes", with: "")
        let uuid = UUID(rawIdentifier: parsed)
        return uuid
    }
    
    public func accept(overrideInHome: Bool = false) {
        @Dependency(\.defaultDatabase) var db
        @Dependency(\.defaultSyncEngine) var syncEngine
        
        Task {
            self.state = .pending
            
            guard let invite else {
                self.state = .fail
                return
            }
            
            guard let id = extractId(from: invite.share.recordID) else {
                print("No id!")
                self.state = .fail
                return
            }
            
            if id == homes.home?.id {
                self.showSameHomeError = true
                return
            }
            
            if !overrideInHome && homes.home != nil {
                self.showSameHomeError = true
                return
            }
            
            do {
                print("DOING JOIN")
                let joined = try await isAlreadyParticipant(invite)
                if joined {
                    print("ALLREADY JOINED")
                } else {
                    print("Not joined?")
                    
                }
                
                try await syncEngine.acceptShare(metadata: invite)
                try await syncEngine.syncChanges()
                
                try await awaitHomeSync(externalId: id)
                try await db.write { db in
                    try DBRecipe
                        .update { recipe in
                            recipe.homeId = id
                        }
                        .execute(db)
                }
                
                self.state = .success
            } catch {
                print("DB Fail \(error.localizedDescription)")
                self.state = .fail
            }
        }
    }
    
    func isAlreadyParticipant(_ metadata: CKShare.Metadata) async throws -> Bool {
        let db = CKContainer.default().sharedCloudDatabase
        do {
            let save = try await db.record(for: metadata.share.recordID)
            let op = try await db.modifyRecords(saving: [], deleting: [save.recordID])
            print(op.deleteResults)
            return true
        } catch let e as CKError {
            switch e.code {
            case .unknownItem, .permissionFailure:
                print("JOIN - UNKNOWN OR PERM \(e.localizedDescription)")
                return false
            default:
                print("JOIN - \(e.localizedDescription)")
                return false
            }
        }
    }
    
    @discardableResult
    func awaitHomeSync(
        externalId: UUID,
        deadline: Duration = .seconds(60)
    ) async throws -> DBHome {
        let start = ContinuousClock.now
        while ContinuousClock.now - start < deadline {
            try await syncEngine.syncChanges()
            let result = try await db.read { db in
                try DBHome
                    .find(externalId)
                    .fetchOne(db)
            }
            if let result {
                return result
            }
            
            try await Task.sleep(for: .milliseconds(300))
        }
        throw NSError(domain: "AwaitHome", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out"])
    }
}

struct SporkSpinnerView: View {
    
    private let scale: CGFloat = 0.88
    
    var body: some View {
        ZStack {
            animatingDots
            logo
        }
    }
    
    private var animatingDots: some View {
        ZStack {
            gradientBackground
                .mask {
                    ZStack {
                        AnimatedDots(delay: 0)
                        AnimatedDots(delay: 0.25)
                            .scaleEffect(scale)
                            .rotationEffect(.degrees(360/48))
                        AnimatedDots(delay: 0.5)
                            .scaleEffect(scale * scale)
                        AnimatedDots(delay: 0.75)
                            .scaleEffect(scale * scale * scale)
                            .rotationEffect(.degrees(360/48))
                    }
                }
        }
    }
    
    private var gradientBackground: some View {
        AngularGradient(colors: [.cyan, .indigo, .pink, .orange, .cyan], center: .center, startAngle: .degrees(-45), endAngle: .degrees(360-45))
    }
    
    private var logo: some View {
        GeometryReader { geo in
            Image("SporkIcon", bundle: .module)
                .renderingMode(.template)
                .resizable()
                .scaleEffect(0.25)
                .foregroundStyle(.secondary)
        }
    }
}

struct AnimatedDots: View {
    let delay: Double
    
    @State private var animating = false
    @State private var rotation = 0.0
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        dots
            .opacity(animating ? 1 : 0)
            .scaleEffect(animating ? 1 : 0.5)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                fadeIn()
            }
            .onReceive(timer) { _ in
                if animating {
                    fadeOut()
                } else {
                    fadeIn()
                }
            }
    }
    
    private func fadeIn() {
        withAnimation(.easeInOut(duration: 1.8).delay(delay)) {
            rotation += 60
            animating = true
        }
    }
    
    private func fadeOut() {
        withAnimation(.easeInOut(duration: 1.8).delay(1 - delay)) {
            rotation += 60
            animating = false
        }
    }
    
    private var dots: some View {
        Canvas { context, size in
            let dimensionOffset = size.width/2
            let image = context.resolve(Image(systemName: "circle.fill"))
            var currentPoint = CGPoint(x: dimensionOffset - image.size.width/2, y: 0)
            
            for _ in 0...24 {
                currentPoint = currentPoint.applying(.init(rotationAngle: Angle.degrees(360/24).radians))
                context.draw(image, at: CGPoint(x: currentPoint.x + dimensionOffset, y: currentPoint.y + dimensionOffset))
            }
        }
        .frame(width: 300, height: 300)
        .rotationEffect(.degrees(360/48))
    }
}

#Preview {
    let database = PreviewSupport.preparePreviewDatabase()

    return NavigationStack {
        HomeInvitePage(demoTitle: "Test Home", demoOwnerName: "Demo User", demoEmail: nil)
            .environment(AppRouter(initialTab: .settings))
            .environment(database)
    }
}
