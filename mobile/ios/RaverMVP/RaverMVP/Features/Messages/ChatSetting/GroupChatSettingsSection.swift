import SwiftUI

struct GroupChatSettingsSection: View {
    let canManageSquad: Bool
    let canDisbandSquad: Bool
    let onOpenSquadProfile: () -> Void
    let onOpenSquadManage: () -> Void
    let onOpenInviteApprovals: () -> Void
    let onDisbandSquad: () -> Void
    let onLeaveSquad: () -> Void
    let isDisbanding: Bool
    let isLeaving: Bool

    var body: some View {
        Button {
            onOpenSquadProfile()
        } label: {
            Label(L("查看小队主页", "View Squad Profile"), systemImage: "person.3.fill")
        }

        Button {
            onOpenSquadManage()
        } label: {
            Label(
                canManageSquad ? L("管理小队", "Manage Squad") : L("查看小队设置", "View Squad Settings"),
                systemImage: "person.3.sequence.fill"
            )
        }
        .disabled(!canManageSquad)

        Button {
            onOpenInviteApprovals()
        } label: {
            Label(
                canManageSquad ? L("邀请审核", "Invite Approvals") : L("邀请审核（仅管理员）", "Invite Approvals (Admin Only)"),
                systemImage: "person.badge.plus"
            )
        }
        .disabled(!canManageSquad)

        Button(role: .destructive) {
            onDisbandSquad()
        } label: {
            Label(
                canDisbandSquad ? L("解散小队", "Disband Squad") : L("解散小队（仅队长）", "Disband Squad (Leader Only)"),
                systemImage: "xmark.circle"
            )
        }
        .disabled(!canDisbandSquad || isDisbanding || isLeaving)

        Button(role: .destructive) {
            onLeaveSquad()
        } label: {
            Label(L("退出小队", "Leave Squad"), systemImage: "rectangle.portrait.and.arrow.right")
        }
        .disabled(isLeaving || isDisbanding)
    }
}
