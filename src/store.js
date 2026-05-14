import { create } from 'zustand'
import { persist } from 'zustand/middleware'

const defaultEarnTasks = [
  { id: 'earn-1', title: 'Chinese Reading', duration: 30, reward: 30, icon: 'BookOpen' },
  { id: 'earn-2', title: 'English Reading', duration: 30, reward: 30, icon: 'BookOpen' },
  { id: 'earn-3', title: 'Outdoor Sports', duration: 30, reward: 60, icon: 'Dumbbell' },
  { id: 'earn-4', title: 'HIIT Workout', duration: 10, reward: 40, icon: 'Dumbbell' },
];

const defaultSpendTasks = [
  { id: 'spend-1', title: 'Video Games', duration: 30, cost: 30, icon: 'Gamepad2' },
  { id: 'spend-2', title: 'Watch TV', duration: 30, cost: 30, icon: 'Tv' },
];

export const useStore = create(
  persist(
    (set) => ({
      availableMinutes: 0,
      totalEarned: 0,
      totalSpent: 0,
      dailyCap: 60, // Default 60 mins daily limit
      todaySpent: 0,
      lastSpentDate: '',
      cooldownUntil: 0,
      cooldownDuration: 20, // Default 20 mins
      parentPIN: '1234', // Default PIN
      hasSeenOnboarding: false,
      earnTasks: defaultEarnTasks,
      spendTasks: defaultSpendTasks,
      
      addMinutes: (minutes) => set((state) => ({ 
        availableMinutes: state.availableMinutes + minutes,
        totalEarned: state.totalEarned + minutes
      })),
      
      setDailyCap: (cap) => set({ dailyCap: cap }),
      setCooldownDuration: (mins) => set({ cooldownDuration: mins }),
      setParentPIN: (pin) => set({ parentPIN: pin }),
      completeOnboarding: () => set({ hasSeenOnboarding: true }),

      recordSpend: (minutesPlayed, minutesCost, triggerCooldown = true) => set((state) => {
        const todayStr = new Date().toISOString().split('T')[0];
        const isNewDay = state.lastSpentDate !== todayStr;
        const newTodaySpent = (isNewDay ? 0 : state.todaySpent) + minutesPlayed;
        
        return {
          availableMinutes: Math.max(0, state.availableMinutes - minutesCost),
          totalSpent: state.totalSpent + minutesCost,
          todaySpent: newTodaySpent,
          lastSpentDate: todayStr,
          cooldownUntil: triggerCooldown 
            ? Date.now() + state.cooldownDuration * 60 * 1000 
            : state.cooldownUntil
        };
      }),
      
      // Earn Tasks CRUD
      addEarnTask: (task) => set((state) => ({ earnTasks: [...state.earnTasks, task] })),
      updateEarnTask: (id, updatedTask) => set((state) => ({
        earnTasks: state.earnTasks.map(t => t.id === id ? { ...t, ...updatedTask } : t)
      })),
      deleteEarnTask: (id) => set((state) => ({
        earnTasks: state.earnTasks.filter(t => t.id !== id)
      })),

      // Spend Tasks CRUD
      addSpendTask: (task) => set((state) => ({ spendTasks: [...state.spendTasks, task] })),
      updateSpendTask: (id, updatedTask) => set((state) => ({
        spendTasks: state.spendTasks.map(t => t.id === id ? { ...t, ...updatedTask } : t)
      })),
      deleteSpendTask: (id) => set((state) => ({
        spendTasks: state.spendTasks.filter(t => t.id !== id)
      })),
    }),
    {
      name: 'kids-time-storage',
      merge: (persistedState, currentState) => ({
        ...currentState,
        ...persistedState,
        earnTasks: persistedState.earnTasks || currentState.earnTasks,
        spendTasks: persistedState.spendTasks || currentState.spendTasks,
      })
    }
  )
)
