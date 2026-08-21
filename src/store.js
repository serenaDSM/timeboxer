import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { getLocalDateKey } from './date.js';
import {
  DEFAULT_POLICY,
  getDayType,
  getEarnBonusCap,
  POLICY_PRESETS,
  PUBLIC_HEALTH_CEILING_MINUTES,
} from './policy.js';
import {
  DEFAULT_EARN_TASKS,
  DEFAULT_SPEND_TASKS,
  migrateEarnTasks,
  migrateSpendTasks,
} from './defaults.js';

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

const migratePolicy = (policy = {}) => {
  if (POLICY_PRESETS[policy.id]) return { ...POLICY_PRESETS[policy.id] };
  return {
    ...DEFAULT_POLICY,
    ...policy,
    id: 'custom',
    name: 'Custom',
  };
};

const migratePersistedState = (persistedState = {}) => {
  const policy = migratePolicy(persistedState.policy);
  const today = getLocalDateKey();
  const dayType = getDayType({ date: new Date(), dayOverrides: persistedState.dayOverrides || {} });
  const earnCap = getEarnBonusCap(policy, dayType);

  return {
    ...persistedState,
    availableMinutes: Math.min(earnCap, clampMinutes(persistedState.availableMinutes)),
    availableMinutesDate: today,
    familyProfile: { ...defaultProfile, ...(persistedState.familyProfile || {}) },
    policy,
    dayOverrides: persistedState.dayOverrides || {},
    dailyBonuses: persistedState.dailyBonuses || {},
    pendingRequests: persistedState.pendingRequests || [],
    recentEvents: persistedState.recentEvents || [],
    childStatus: persistedState.childStatus || { kind: 'idle', updatedAt: Date.now() },
    earnTasks: migrateEarnTasks(persistedState.earnTasks),
    spendTasks: migrateSpendTasks(persistedState.spendTasks),
    testTimerSeconds: Math.min(300, Math.max(0, Math.round(Number(persistedState.testTimerSeconds) || 0))),
  };
};

export const useStore = create(
  persist(
    (set) => ({
      availableMinutes: 0,
      availableMinutesDate: getLocalDateKey(),
      totalEarned: 0,
      totalSpent: 0,
      todaySpent: 0,
      lastSpentDate: '',
      cooldownUntil: 0,
      testTimerSeconds: 0,
      parentPIN: '1234',
      hasSeenOnboarding: false,
      earnTasks: DEFAULT_EARN_TASKS,
      spendTasks: DEFAULT_SPEND_TASKS,

      familyProfile: defaultProfile,
      policy: { ...DEFAULT_POLICY },
      dayOverrides: {},
      dailyBonuses: {},
      pendingRequests: [],
      recentEvents: [],
      childStatus: { kind: 'idle', updatedAt: Date.now() },
      lastPolicyUpdatedAt: Date.now(),

      addMinutes: (minutes) => set((state) => {
        const today = getLocalDateKey();
        const currentEarned = state.availableMinutesDate === today ? state.availableMinutes : 0;
        const dayType = getDayType({ date: new Date(), dayOverrides: state.dayOverrides });
        const earnCap = getEarnBonusCap(state.policy, dayType);
        const credited = Math.min(
          Math.max(0, earnCap - currentEarned),
          clampMinutes(minutes),
        );

        return {
          availableMinutes: currentEarned + credited,
          availableMinutesDate: today,
          totalEarned: state.totalEarned + credited,
          recentEvents: appendEvent(state.recentEvents, {
            type: credited > 0 ? 'earned' : 'earn-cap',
            message: credited > 0
              ? `${state.familyProfile.childName} earned ${credited} bonus minutes.`
              : `${state.familyProfile.childName} completed the activity; today’s earnable bonus is full.`,
          }),
        };
      }),

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
          ...(updates.schoolEarnCapMinutes !== undefined && { schoolEarnCapMinutes: clampMinutes(updates.schoolEarnCapMinutes) }),
          ...(updates.weekendEarnCapMinutes !== undefined && { weekendEarnCapMinutes: clampMinutes(updates.weekendEarnCapMinutes) }),
          ...(updates.holidayEarnCapMinutes !== undefined && { holidayEarnCapMinutes: clampMinutes(updates.holidayEarnCapMinutes) }),
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
        return {
          pendingRequests: updatedRequests,
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
        const today = getLocalDateKey();
        const dayType = getDayType({ date: new Date(), dayOverrides: state.dayOverrides });
        const nextMinutes = Math.min(
          getEarnBonusCap(state.policy, dayType),
          clampMinutes(minutes),
        );
        return {
          availableMinutes: nextMinutes,
          availableMinutesDate: today,
          recentEvents: appendEvent(state.recentEvents, {
            type: 'test-adjustment',
            message: `Parent set today’s earned bonus to ${nextMinutes} minutes.`,
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
        availableMinutesDate: getLocalDateKey(),
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

      recordSpend: (minutesPlayed, triggerCooldown = true) => set((state) => {
        const todayStr = getLocalDateKey();
        const isNewDay = state.lastSpentDate !== todayStr;
        const newTodaySpent = (isNewDay ? 0 : state.todaySpent) + minutesPlayed;
        return {
          totalSpent: state.totalSpent + minutesPlayed,
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
      version: 6,
      migrate: migratePersistedState,
      merge: (persistedState, currentState) => ({
        ...currentState,
        ...persistedState,
        familyProfile: { ...currentState.familyProfile, ...(persistedState.familyProfile || {}) },
        policy: { ...currentState.policy, ...(persistedState.policy || {}) },
        earnTasks: migrateEarnTasks(persistedState.earnTasks || currentState.earnTasks),
        spendTasks: migrateSpendTasks(persistedState.spendTasks || currentState.spendTasks),
      }),
    },
  ),
);
