import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { getLocalDateKey } from './date.js';
import { DEFAULT_POLICY, POLICY_PRESETS, PUBLIC_HEALTH_CEILING_MINUTES } from './policy.js';

const defaultEarnTasks = [
  { id: 'earn-1', title: 'Chinese Reading', duration: 30, reward: 30, icon: 'BookOpen' },
  { id: 'earn-2', title: 'English Reading', duration: 30, reward: 30, icon: 'BookOpen' },
  { id: 'earn-3', title: 'Outdoor Play', duration: 30, reward: 30, icon: 'Dumbbell' },
];

const defaultSpendTasks = [
  { id: 'spend-1', title: 'Video Games', duration: 30, cost: 30, icon: 'Gamepad2' },
  { id: 'spend-2', title: 'Watch Videos', duration: 30, cost: 30, icon: 'Tv' },
];

const defaultProfile = {
  childName: 'Alex',
  age: 11,
  bedtime: '20:30',
  timezone: 'Pacific/Auckland',
};

const createEvent = (event) => ({
  id: `event-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
  createdAt: Date.now(),
  ...event,
});

const appendEvent = (events, event) => [createEvent(event), ...(events || [])].slice(0, 50);

const clampMinutes = (value, maximum = PUBLIC_HEALTH_CEILING_MINUTES) => (
  Math.min(maximum, Math.max(0, Math.round(Number(value) || 0)))
);

export const useStore = create(
  persist(
    (set) => ({
      availableMinutes: 0,
      totalEarned: 0,
      totalSpent: 0,
      todaySpent: 0,
      lastSpentDate: '',
      cooldownUntil: 0,
      testTimerSeconds: 0,
      parentPIN: '1234',
      hasSeenOnboarding: false,
      earnTasks: defaultEarnTasks,
      spendTasks: defaultSpendTasks,

      familyProfile: defaultProfile,
      policy: { ...DEFAULT_POLICY },
      dayOverrides: {},
      dailyBonuses: {},
      pendingRequests: [],
      recentEvents: [],
      childStatus: { kind: 'idle', updatedAt: Date.now() },
      lastPolicyUpdatedAt: Date.now(),

      addMinutes: (minutes) => set((state) => ({
        availableMinutes: state.availableMinutes + minutes,
        totalEarned: state.totalEarned + minutes,
        recentEvents: appendEvent(state.recentEvents, {
          type: 'earned',
          message: `${state.familyProfile.childName} earned ${minutes} minutes.`,
        }),
      })),

      updateFamilyProfile: (updates) => set((state) => ({
        familyProfile: { ...state.familyProfile, ...updates },
        lastPolicyUpdatedAt: Date.now(),
      })),

      applyPreset: (presetId) => set((state) => {
        const preset = POLICY_PRESETS[presetId];
        if (!preset) return state;
        return {
          policy: { ...preset },
          lastPolicyUpdatedAt: Date.now(),
          recentEvents: appendEvent(state.recentEvents, {
            type: 'policy',
            message: `Parent changed the plan to ${preset.name}.`,
          }),
        };
      }),

      updatePolicy: (updates) => set((state) => ({
        policy: {
          ...state.policy,
          ...updates,
          ...(updates.schoolLimit !== undefined && { schoolLimit: clampMinutes(updates.schoolLimit) }),
          ...(updates.weekendLimit !== undefined && { weekendLimit: clampMinutes(updates.weekendLimit) }),
          ...(updates.holidayLimit !== undefined && { holidayLimit: clampMinutes(updates.holidayLimit) }),
          ...(updates.maxSessionMinutes !== undefined && { maxSessionMinutes: clampMinutes(updates.maxSessionMinutes, 60) }),
        },
        lastPolicyUpdatedAt: Date.now(),
      })),

      setDayType: (dateKey, dayType) => set((state) => ({
        dayOverrides: { ...state.dayOverrides, [dateKey]: dayType },
        lastPolicyUpdatedAt: Date.now(),
        recentEvents: appendEvent(state.recentEvents, {
          type: 'policy',
          message: `Parent marked today as ${dayType}.`,
        }),
      })),

      submitExtraTimeRequest: (minutes = 10) => set((state) => {
        const hasPending = state.pendingRequests.some((request) => request.status === 'pending');
        if (hasPending) return state;
        const request = {
          id: `request-${Date.now()}`,
          type: 'extra-time',
          minutes,
          status: 'pending',
          createdAt: Date.now(),
          dateKey: getLocalDateKey(),
        };
        return {
          pendingRequests: [request, ...state.pendingRequests].slice(0, 20),
          recentEvents: appendEvent(state.recentEvents, {
            type: 'request',
            message: `${state.familyProfile.childName} asked for ${minutes} extra minutes.`,
          }),
        };
      }),

      resolveExtraTimeRequest: (requestId, approved) => set((state) => {
        const request = state.pendingRequests.find((item) => item.id === requestId);
        if (!request || request.status !== 'pending') return state;
        const updatedRequests = state.pendingRequests.map((item) => (
          item.id === requestId
            ? { ...item, status: approved ? 'approved' : 'declined', resolvedAt: Date.now() }
            : item
        ));
        const approvedMinutes = approved ? request.minutes : 0;
        return {
          pendingRequests: updatedRequests,
          availableMinutes: state.availableMinutes + approvedMinutes,
          dailyBonuses: approved
            ? {
                ...state.dailyBonuses,
                [request.dateKey]: clampMinutes(
                  (state.dailyBonuses[request.dateKey] || 0) + request.minutes,
                  60,
                ),
              }
            : state.dailyBonuses,
          recentEvents: appendEvent(state.recentEvents, {
            type: approved ? 'approved' : 'declined',
            message: approved
              ? `Parent approved ${request.minutes} extra minutes.`
              : 'Parent declined the extra-time request.',
          }),
        };
      }),

      logEvent: (event) => set((state) => ({
        recentEvents: appendEvent(state.recentEvents, event),
      })),

      setChildStatus: (status) => set({
        childStatus: { ...status, updatedAt: Date.now() },
      }),

      setTestTimerSeconds: (seconds) => set({
        testTimerSeconds: Math.min(300, Math.max(0, Math.round(Number(seconds) || 0))),
      }),
      setAvailableMinutes: (minutes) => set((state) => {
        const nextMinutes = Math.min(600, Math.max(0, Math.round(Number(minutes) || 0)));
        return {
          availableMinutes: nextMinutes,
          recentEvents: appendEvent(state.recentEvents, {
            type: 'test-adjustment',
            message: `Parent set the test balance to ${nextMinutes} minutes.`,
          }),
        };
      }),

      setParentPIN: (pin) => set({ parentPIN: pin }),
      completeOnboarding: ({ profile, presetId } = {}) => set((state) => ({
        hasSeenOnboarding: true,
        familyProfile: { ...state.familyProfile, ...(profile || {}) },
        policy: { ...(POLICY_PRESETS[presetId] || state.policy) },
        lastPolicyUpdatedAt: Date.now(),
      })),

      resetAllData: () => set({
        availableMinutes: 0,
        totalEarned: 0,
        totalSpent: 0,
        todaySpent: 0,
        lastSpentDate: '',
        cooldownUntil: 0,
        dailyBonuses: {},
        pendingRequests: [],
        recentEvents: [],
        childStatus: { kind: 'idle', updatedAt: Date.now() },
      }),

      recordSpend: (minutesPlayed, minutesCost, triggerCooldown = true) => set((state) => {
        const todayStr = getLocalDateKey();
        const isNewDay = state.lastSpentDate !== todayStr;
        const newTodaySpent = (isNewDay ? 0 : state.todaySpent) + minutesPlayed;
        return {
          availableMinutes: Math.max(0, state.availableMinutes - minutesCost),
          totalSpent: state.totalSpent + minutesCost,
          todaySpent: newTodaySpent,
          lastSpentDate: todayStr,
          cooldownUntil: triggerCooldown
            ? Date.now() + state.policy.cooldownMinutes * 60 * 1000
            : state.cooldownUntil,
          recentEvents: appendEvent(state.recentEvents, {
            type: 'played',
            message: `${state.familyProfile.childName} used ${minutesPlayed} entertainment minutes.`,
          }),
        };
      }),

      addEarnTask: (task) => set((state) => ({ earnTasks: [...state.earnTasks, task] })),
      updateEarnTask: (id, updatedTask) => set((state) => ({
        earnTasks: state.earnTasks.map((task) => task.id === id ? { ...task, ...updatedTask } : task),
      })),
      deleteEarnTask: (id) => set((state) => ({
        earnTasks: state.earnTasks.filter((task) => task.id !== id),
      })),
      addSpendTask: (task) => set((state) => ({ spendTasks: [...state.spendTasks, task] })),
      updateSpendTask: (id, updatedTask) => set((state) => ({
        spendTasks: state.spendTasks.map((task) => task.id === id ? { ...task, ...updatedTask } : task),
      })),
      deleteSpendTask: (id) => set((state) => ({
        spendTasks: state.spendTasks.filter((task) => task.id !== id),
      })),
    }),
    {
      name: 'kids-time-storage',
      version: 4,
      migrate: (persistedState) => ({
        ...persistedState,
        familyProfile: { ...defaultProfile, ...(persistedState.familyProfile || {}) },
        policy: { ...DEFAULT_POLICY, ...(persistedState.policy || {}) },
        dayOverrides: persistedState.dayOverrides || {},
        dailyBonuses: persistedState.dailyBonuses || {},
        pendingRequests: persistedState.pendingRequests || [],
        recentEvents: persistedState.recentEvents || [],
        childStatus: persistedState.childStatus || { kind: 'idle', updatedAt: Date.now() },
        testTimerSeconds: Math.min(300, Math.max(0, Math.round(Number(persistedState.testTimerSeconds) || 0))),
      }),
      merge: (persistedState, currentState) => ({
        ...currentState,
        ...persistedState,
        familyProfile: { ...currentState.familyProfile, ...(persistedState.familyProfile || {}) },
        policy: { ...currentState.policy, ...(persistedState.policy || {}) },
        earnTasks: persistedState.earnTasks || currentState.earnTasks,
        spendTasks: persistedState.spendTasks || currentState.spendTasks,
      }),
    },
  ),
);
