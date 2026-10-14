import Models
import Environment
import SwiftUI

struct RecipeLibrarySecondaryActions: View {
    let canOrganize: Bool
    let showsDiscovery: Bool
    let repository: RecipeOrganizationRepository
    let homeID: UUID?

    var body: some View {
        if canOrganize {
            NavigationLink {
                RecipeOrganizationManagePage(repository: repository, homeId: homeID)
            } label: {
                Label("Folders & Tags", systemImage: "folder.badge.gearshape")
            }
        } else {
            NavigationLink {
                RecipeOrganizationLockedPage()
            } label: {
                Label("Folders & Tags", systemImage: "folder.badge.gearshape")
            }
        }

        if showsDiscovery {
            NavigationLink {
                RecipeDiscoveryPage()
            } label: {
                Label("Discover Recipes", systemImage: "sparkles")
            }
        }
    }
}
