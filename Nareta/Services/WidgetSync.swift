import Foundation
import SwiftData
import WidgetKit

/// ウィジェット用のデータを書き出して、表示を更新する
@MainActor
enum WidgetSync {
    static func update(context: ModelContext, now: Date = .now) {
        let goals = (try? context.fetch(FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let completions = (try? context.fetch(FetchDescriptor<GoalCompletion>())) ?? []
        let routines = (try? context.fetch(FetchDescriptor<RoutineAnchor>())) ?? []
        let byGoal = Dictionary(grouping: completions, by: \.goalId)
        let service = RewardService(context: context)
        let pool = service.currentPool(now: now)
        let next = service.nextReward()

        let items = goals
            .filter { GoalService.showsInToday($0, byGoal[$0.id] ?? [], now: now) }
            .map { goal in
                WidgetSnapshot.GoalItem(
                    id: goal.id,
                    title: goal.title,
                    reward: goal.rewardAmount,
                    done: GoalService.isCompletedToday(byGoal[goal.id] ?? [], now: now),
                    trigger: TriggerService.label(for: goal, routines: routines)
                )
            }
        let earned = completions.filter { $0.completedAt.isSameDay(as: now) }.reduce(0) { $0 + $1.rewardAmount }

        WidgetSnapshot(
            generatedAt: now,
            available: pool?.availableAmount ?? 0,
            poolTotal: pool?.totalAmount ?? 0,
            unlocked: pool?.unlockedAmount ?? 0,
            todayEarned: earned,
            goals: items,
            nextRewardName: next?.name,
            nextRewardPrice: next?.price,
            streak: GoalService.dayStreak(completions, now: now)
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
