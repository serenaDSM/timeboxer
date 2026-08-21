import { useCallback, useEffect, useState } from 'react';
import { LockKeyhole } from 'lucide-react';
import { useStore } from './store.js';
import { getLocalDateKey } from './date.js';
import {
  getBaseDailyLimit,
  getBedtimeCutoff,
  getDailyLimit,
  getDayType,
  getEarnBonusCap,
  getEffectivePlayDuration,
  getTodayAvailableMinutes,
  isInsideBedtimeBlock,
  shouldTriggerCooldown,
} from './policy.js';
import { validateTaskInput } from './rules.js';
import Timer from './components/Timer.jsx';
import Onboarding from './components/Onboarding.jsx';
import ChildDashboard from './components/ChildDashboard.jsx';
import ParentDashboard from './components/ParentDashboard.jsx';
import BrandLogo from './components/BrandLogo.jsx';
import { notifyNative } from './nativeBridge.js';
import { useFamilySync } from './useFamilySync.js';

const getInitialRole = () => {
  const queryRole = new URLSearchParams(window.location.search).get('view');
  const hashRole = new URLSearchParams(window.location.hash.replace(/^#/, '')).get('view');
  const requested = queryRole || hashRole;
  return requested === 'parent' ? 'parent-locked' : 'child';
};

function App() {
  const syncStatus = useFamilySync();
  const {
    availableMinutes,
    availableMinutesDate,
    todaySpent,
    lastSpentDate,
    cooldownUntil,
    testTimerSeconds,
    parentPIN,
    hasSeenOnboarding,
    earnTasks,
    spendTasks,
    familyProfile,
    policy,
    dayOverrides,
    dailyBonuses,
    pendingRequests,
    recentEvents,
    childStatus,
    addMinutes,
    updateFamilyProfile,
    applyPreset,
    updatePolicy,
    setDayType,
    submitExtraTimeRequest,
    resolveExtraTimeRequest,
    logEvent,
    setChildStatus,
    setTestTimerSeconds,
    setAvailableMinutes,
    setParentPIN,
    completeOnboarding,
    resetAllData,
    recordSpend,
    addEarnTask,
    updateEarnTask,
    deleteEarnTask,
    addSpendTask,
    updateSpendTask,
    deleteSpendTask,
  } = useStore();

  const [activeTimer, setActiveTimer] = useState(null);
  const [role, setRole] = useState(getInitialRole);
  const [now, setNow] = useState(0);
  const [pinValue, setPinValue] = useState('');
  const [pinError, setPinError] = useState('');

  useEffect(() => {
    const updateClock = () => setNow(Date.now());
    updateClock();
    const interval = window.setInterval(updateClock, 1000);
    return () => window.clearInterval(interval);
  }, []);

  // Zustand persistence is local-first. Rehydrate on storage changes so a child
  // tab and a parent tab behave like two linked clients during the prototype.
  useEffect(() => {
    const syncLinkedTab = (event) => {
      if (event.key === 'kids-time-storage') {
        useStore.persist.rehydrate();
      }
    };
    window.addEventListener('storage', syncLinkedTab);
    return () => window.removeEventListener('storage', syncLinkedTab);
  }, []);

  useEffect(() => {
    const handleNativeEvent = (event) => {
      const detail = event.detail || {};
      if (detail.type === 'application-blocked') {
        logEvent({
          type: 'blocked',
          message: detail.payload?.message || 'A restricted Mac app was blocked.',
        });
      }
      if (detail.type === 'shield-request-extra') {
        submitExtraTimeRequest(Number(detail.payload?.minutes) || 10);
      }
      if (detail.type === 'view-mode') {
        setRole(detail.payload?.view === 'parent' ? 'parent-locked' : 'child');
        setPinValue('');
        setPinError('');
      }
    };
    window.addEventListener('timeboxer:native-event', handleNativeEvent);
    return () => window.removeEventListener('timeboxer:native-event', handleNativeEvent);
  }, [logEvent, submitExtraTimeRequest]);

  useEffect(() => {
    notifyNative('web-ready');
  }, []);

  const currentDate = now ? new Date(now) : null;
  const todayKey = currentDate ? getLocalDateKey(currentDate) : '';
  const dayType = currentDate ? getDayType({ date: currentDate, dayOverrides }) : 'school';
  const actualTodaySpent = lastSpentDate === todayKey ? todaySpent : 0;
  const baseDailyLimit = getBaseDailyLimit(policy, dayType);
  const earnBonusCap = getEarnBonusCap(policy, dayType);
  const earnedMinutesToday = availableMinutesDate === todayKey
    ? Math.min(availableMinutes, earnBonusCap)
    : 0;
  const parentBonusToday = dailyBonuses[todayKey] || 0;
  const dailyLimit = getDailyLimit({
    policy,
    dayType,
    earnedMinutes: earnedMinutesToday,
    bonusMinutes: parentBonusToday,
  });
  const todayAvailable = getTodayAvailableMinutes({
    todaySpent: actualTodaySpent,
    dailyLimit,
  });
  const cooldownRemaining = now ? Math.max(0, cooldownUntil - now) : 0;
  const bedtimeCutoff = getBedtimeCutoff(familyProfile.bedtime, policy.bedtimeBufferMinutes);
  const bedtimeBlocked = currentDate ? isInsideBedtimeBlock({
    date: currentDate,
    bedtime: familyProfile.bedtime,
    bufferMinutes: policy.bedtimeBufferMinutes,
  }) : false;

  useEffect(() => {
    if (!todayKey) return;
    notifyNative('policy-snapshot', {
      childName: familyProfile.childName,
      bedtime: familyProfile.bedtime,
      bedtimeBufferMinutes: policy.bedtimeBufferMinutes,
      schoolLimit: policy.schoolLimit,
      weekendLimit: policy.weekendLimit,
      holidayLimit: policy.holidayLimit,
      dayOverride: dayOverrides[todayKey] || null,
      usedMinutesToday: actualTodaySpent,
      bonusMinutesToday: earnedMinutesToday + parentBonusToday,
    });
  }, [
    actualTodaySpent,
    dayOverrides,
    earnedMinutesToday,
    familyProfile.bedtime,
    familyProfile.childName,
    policy.bedtimeBufferMinutes,
    policy.holidayLimit,
    policy.schoolLimit,
    policy.weekendLimit,
    parentBonusToday,
    todayKey,
  ]);

  const updateRoleInUrl = (nextRole) => {
    const url = new URL(window.location.href);
    url.searchParams.set('view', nextRole);
    window.history.replaceState({}, '', url);
  };

  const openParent = () => {
    setPinValue('');
    setPinError('');
    setRole('parent-locked');
    updateRoleInUrl('parent');
  };

  const unlockParent = (event) => {
    event.preventDefault();
    if (pinValue !== parentPIN) {
      setPinError('Incorrect PIN. Please try again.');
      return;
    }
    setPinValue('');
    setPinError('');
    setRole('parent');
    updateRoleInUrl('parent');
  };

  const openChild = () => {
    setRole('child');
    updateRoleInUrl('child');
  };

  const openChildTab = () => {
    const url = new URL(window.location.href);
    url.searchParams.set('view', 'child');
    window.open(url, '_blank', 'noopener,noreferrer');
  };

  const isEarnTimerFullscreenReady = () => (
    Boolean(document.fullscreenElement)
    || (window.innerWidth >= window.screen.availWidth - 100
      && window.innerHeight >= window.screen.availHeight - 250)
  );

  const startEarn = async (task) => {
    if (earnedMinutesToday >= earnBonusCap) {
      window.alert('Today’s earnable bonus is complete. Enjoy the activities without collecting more screen time.');
      return;
    }
    if (testTimerSeconds <= 0 && !isEarnTimerFullscreenReady()) {
      try {
        await document.documentElement.requestFullscreen();
      } catch {
        window.alert('Please maximise the window or allow full screen to start focus time.');
        return;
      }
    }
    setActiveTimer({
      mode: 'earn',
      duration: task.duration,
      reward: task.reward,
      taskTitle: task.title,
    });
    setChildStatus({ kind: 'earning', taskTitle: task.title });
    logEvent({ type: 'started', message: `${familyProfile.childName} started ${task.title}.` });
    notifyNative('timer-started', { mode: 'earn', taskTitle: task.title, duration: task.duration });
  };

  const blockPlay = (message) => {
    window.alert(message);
    logEvent({ type: 'blocked', message: `${familyProfile.childName} was blocked: ${message}` });
    notifyNative('entertainment-blocked', { message });
  };

  const startSpend = (task) => {
    if (bedtimeBlocked) {
      blockPlay('Entertainment is closed for bedtime.');
      return;
    }
    if (cooldownRemaining > 0) {
      blockPlay('An eye break is still in progress.');
      return;
    }

    const remainingDailyMinutes = Math.max(0, dailyLimit - actualTodaySpent);
    const duration = getEffectivePlayDuration({
      requestedDuration: task.duration,
      remainingDailyMinutes,
      maxSessionMinutes: policy.maxSessionMinutes,
    });
    if (duration < 1) {
      blockPlay(remainingDailyMinutes < 1
        ? 'Today’s entertainment limit has been reached.'
        : 'Entertainment is not available right now.');
      return;
    }

    setActiveTimer({ mode: 'spend', duration, taskTitle: task.title });
    setChildStatus({
      kind: 'playing',
      taskTitle: task.title,
      startedAt: Date.now(),
      expectedEndAt: Date.now() + (testTimerSeconds > 0 ? testTimerSeconds : duration * 60) * 1000,
    });
    logEvent({ type: 'started', message: `${familyProfile.childName} started ${task.title} for ${duration} minutes.` });
    notifyNative('timer-started', { mode: 'spend', taskTitle: task.title, duration });
  };

  const handleTimerComplete = useCallback((duration, extraMinutes = 0) => {
    if (!activeTimer) return;
    if (activeTimer.mode === 'earn') {
      addMinutes(activeTimer.reward + Math.min(30, extraMinutes));
    } else {
      recordSpend(duration, true);
    }
    setChildStatus({ kind: 'idle' });
    setActiveTimer(null);
  }, [activeTimer, addMinutes, recordSpend, setChildStatus]);

  const handleTimerCancel = useCallback((playedMinutes = null) => {
    if (!activeTimer) return;
    if (activeTimer.mode === 'spend' && playedMinutes !== null && playedMinutes > 0) {
      recordSpend(
        playedMinutes,
        shouldTriggerCooldown(playedMinutes, policy.cooldownTriggerMinutes),
      );
    } else if (activeTimer.mode === 'earn') {
      logEvent({ type: 'stopped', message: `${familyProfile.childName} left ${activeTimer.taskTitle} before finishing.` });
    }
    setChildStatus({ kind: 'idle' });
    setActiveTimer(null);
  }, [activeTimer, familyProfile.childName, logEvent, policy.cooldownTriggerMinutes, recordSpend, setChildStatus]);

  const promptTask = (task, type) => {
    const title = window.prompt('Activity name:', task?.title || '');
    if (title === null) return;
    const duration = window.prompt('Duration in minutes:', String(task?.duration || 30));
    if (duration === null) return;
    const value = type === 'earn'
      ? window.prompt('Bonus entertainment minutes earned:', String(task?.reward || 5))
      : duration;
    if (value === null) return;
    const validation = validateTaskInput({ title, duration, value, type });
    if (!validation.ok) {
      window.alert(validation.message);
      return;
    }
    const nextTask = {
      ...(task || {}),
      id: task?.id || `${type}-${Date.now()}`,
      title: validation.title,
      duration: validation.duration,
      icon: task?.icon || (type === 'earn' ? 'Sparkles' : 'Gamepad2'),
      ...(type === 'earn' ? { reward: validation.value } : {}),
    };
    if (task) {
      if (type === 'earn') updateEarnTask(task.id, nextTask);
      else updateSpendTask(task.id, nextTask);
    } else if (type === 'earn') addEarnTask(nextTask);
    else addSpendTask(nextTask);
  };

  const deleteTask = (id, type) => {
    if (!window.confirm('Delete this activity?')) return;
    if (type === 'earn') deleteEarnTask(id);
    else deleteSpendTask(id);
  };

  const changePIN = () => {
    const current = window.prompt('Current parent PIN:');
    if (current !== parentPIN) {
      if (current !== null) window.alert('Incorrect PIN.');
      return;
    }
    const next = window.prompt('New parent PIN:');
    if (next?.trim()) {
      setParentPIN(next.trim());
      window.alert('Parent PIN updated.');
    }
  };

  const resetData = () => {
    if (window.confirm('Reset today’s bonus, usage, requests and activity history?')) resetAllData();
  };

  if (!hasSeenOnboarding) {
    return <Onboarding onComplete={completeOnboarding} />;
  }

  if (role === 'parent-locked') {
    return (
      <div className="flex min-h-[100dvh] items-center justify-center bg-[#f8faf8] p-5 text-slate-950">
        <form onSubmit={unlockParent} className="w-full max-w-sm rounded-[28px] border border-slate-200 bg-white p-7 text-center shadow-xl">
          <BrandLogo compact className="justify-center" />
          <div className="mx-auto mt-6 flex h-14 w-14 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-600"><LockKeyhole size={24} /></div>
          <h1 className="mt-5 text-2xl font-black">Parent dashboard</h1>
          <p className="mt-2 text-sm text-slate-400">Enter the parent PIN to manage the family plan.</p>
          <input
            autoFocus
            type="password"
            inputMode="numeric"
            aria-label="Parent PIN"
            value={pinValue}
            onChange={(event) => {
              setPinValue(event.target.value);
              if (pinError) setPinError('');
            }}
            className="mt-6 w-full rounded-2xl border border-slate-200 px-4 py-3 text-center text-xl font-black tracking-[0.35em] outline-none focus:border-emerald-500"
            placeholder="••••"
          />
          <div className="mt-2 min-h-5 text-sm font-bold text-red-500">{pinError}</div>
          <button type="submit" className="mt-2 w-full rounded-2xl bg-[#35d532] py-3 font-black text-slate-950 hover:bg-emerald-400">Unlock</button>
          <button type="button" onClick={openChild} className="mt-3 w-full py-2 text-sm font-bold text-slate-400 hover:text-slate-950">Return to child view</button>
        </form>
      </div>
    );
  }

  if (activeTimer) {
    return (
      <Timer
        mode={activeTimer.mode}
        duration={activeTimer.duration}
        testTimerSeconds={testTimerSeconds}
        parentPIN={parentPIN}
        onComplete={handleTimerComplete}
        onCancel={handleTimerCancel}
      />
    );
  }

  if (role === 'parent') {
    return (
      <ParentDashboard
        profile={familyProfile}
        policy={policy}
        dayType={dayType}
        todayKey={todayKey}
        dailyLimit={dailyLimit}
        baseDailyLimit={baseDailyLimit}
        todaySpent={actualTodaySpent}
        todayAvailable={todayAvailable}
        earnedMinutesToday={earnedMinutesToday}
        earnBonusCap={earnBonusCap}
        parentBonusToday={parentBonusToday}
        testTimerSeconds={testTimerSeconds}
        childStatus={childStatus}
        pendingRequests={pendingRequests}
        recentEvents={recentEvents}
        earnTasks={earnTasks}
        spendTasks={spendTasks}
        syncStatus={syncStatus}
        onOpenChild={openChild}
        onOpenChildTab={openChildTab}
        onApplyPreset={applyPreset}
        onUpdatePolicy={updatePolicy}
        onUpdateProfile={updateFamilyProfile}
        onSetDayType={setDayType}
        onResolveRequest={resolveExtraTimeRequest}
        onAddTask={(type) => promptTask(null, type)}
        onEditTask={promptTask}
        onDeleteTask={deleteTask}
        onChangePIN={changePIN}
        onSetTestTimerSeconds={setTestTimerSeconds}
        onSetAvailableMinutes={setAvailableMinutes}
        onReset={resetData}
      />
    );
  }

  const latestPendingRequest = pendingRequests.find((request) => request.status === 'pending');
  return (
    <ChildDashboard
      profile={familyProfile}
      policy={policy}
      dayType={dayType}
      dailyLimit={dailyLimit}
      baseDailyLimit={baseDailyLimit}
      todaySpent={actualTodaySpent}
      todayAvailable={todayAvailable}
      earnedMinutesToday={earnedMinutesToday}
      earnBonusCap={earnBonusCap}
      cooldownRemaining={cooldownRemaining}
      bedtimeCutoff={bedtimeCutoff}
      bedtimeBlocked={bedtimeBlocked}
      earnTasks={earnTasks}
      spendTasks={spendTasks}
      pendingRequest={latestPendingRequest}
      onEarn={startEarn}
      onSpend={startSpend}
      onRequestExtra={() => {
        submitExtraTimeRequest(10);
        notifyNative('extra-time-requested', { minutes: 10 });
      }}
      onOpenParent={openParent}
    />
  );
}

export default App;
