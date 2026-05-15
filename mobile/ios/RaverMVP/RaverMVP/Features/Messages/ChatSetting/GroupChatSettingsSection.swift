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
            Label(LT("查看小队主页", "View Squad Profile", "Squad ホームを見る"), systemImage: "person.3.fill")
        }

        Button {
            onOpenSquadManage()
        } label: {
            Label(
                canManageSquad ? LT("管理小队", "Manage Squad", "Squad を管理") : LT("查看小队设置", "View Squad Settings", "Squad 設定を見る"),
                systemImage: "person.3.sequence.fill"
            )
        }
        .disabled(!canManageSquad)

        Button {
            onOpenInviteApprovals()
        } label: {
            Label(
                canManageSquad ? LT("邀请审核", "Invite Approvals", "招待の承認") : LT("邀请审核（仅管理员）", "Invite Approvals (Admin Only)", "招待の承認（管理者のみ）"),
                systemImage: "person.badge.plus"
            )
        }
        .disabled(!canManageSquad)

        Button(role: .destructive) {
            onDisbandSquad()
        } label: {
            Label(
                canDisbandSquad ? LT("解散小队", "Disband Squad", "Squad を解散") : LT("解散小队（仅队长）", "Disband Squad (Leader Only)", "Squad を解散（リーダーのみ）"),
                systemImage: "xmark.circle"
            )
        }
        .disabled(!canDisbandSquad || isDisbanding || isLeaving)

        Button(role: .destructive) {
            onLeaveSquad()
        } label: {
            Label(LT("退出小队", "Leave Squad", "Squad を退出"), systemImage: "rectangle.portrait.and.arrow.right")
        }
        .disabled(isLeaving || isDisbanding)
    }
}
