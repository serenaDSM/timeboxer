import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Activity,
  AlertTriangle,
  AppWindow,
  Bell,
  Check,
  ChevronDown,
  ChevronRight,
  Clock3,
  Gamepad2,
  Gauge,
  Gift,
  Globe2,
  Moon,
  Pencil,
  Plus,
  RotateCcw,
  Settings,
  ShieldCheck,
  Smartphone,
  Trash2,
  WifiOff,
  X,
} from 'lucide-react';
import {
  getParentAlertEvents,
  getParentAlertMetadata,
  getUnreadParentAlerts,
  pickBrowserAlert,
} from '../parentAlerts.js';
import {
  DAY_TYPES,
  getMaximumDailyLimit,
  POLICY_PRESETS,
  normalizeDomainInput,
  WEB_RESTRICTION_OPTIONS,
} from '../policy.js';
import BrandLogo from './BrandLogo.jsx';

const formatEventTime = (timestamp) => new Intl.DateTimeFormat('en-NZ', {
  hour: 'numeric',
  minute: '2-digit',
}).format(new Date(timestamp));

const PARENT_ALERTS_ENABLED_KEY = 'timeboxer-parent-alerts-enabled';
const PARENT_ALERTS_READ_AT_KEY = 'timeboxer-parent-alerts-read-at';

const alertStyle = {
  critical: {
    card: 'border-red-200 bg-red-50',
    icon: 'bg-red-100 text-red-600',
    dot: 'bg-red-500',
  },
  action: {
    card: 'border-amber-200 bg-amber-50',
    icon: 'bg-amber-100 text-amber-600',
    dot: 'bg-amber-500',
  },
  positive: {
    card: 'border-emerald-200 bg-emerald-50',
    icon: 'bg-emerald-100 text-emerald-600',
    dot: 'bg-emerald-500',
  },
  info: {
    card: 'border-slate-200 bg-slate-50',
    icon: 'bg-slate-100 text-slate-500',
    dot: 'bg-slate-400',
  },
};

function AccordionSection({
  icon: Icon,
  eyebrow,
  title,
  description,
  badge,
  defaultOpen = false,
  className = '',
  children,
}) {
  const [open, setOpen] = useState(defaultOpen);

  return (
    <section className={`rounded-[24px] border border-slate-200 bg-white shadow-sm ${className}`}>
      <button
        type="button"
        aria-expanded={open}
        onClick={() => setOpen((value) => !value)}
        className="flex w-full items-center gap-3 p-4 text-left"
      >
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-600">
          <Icon size={21} />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block text-[11px] font-black uppercase tracking-[0.14em] text-emerald-600">{eyebrow}</span>
          <span className="mt-0.5 block text-lg font-black">{title}</span>
          {description && <span className="mt-0.5 block text-xs leading-relaxed text-slate-400">{description}</span>}
        </span>
        {badge && <span className="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-black text-slate-500">{badge}</span>}
        <ChevronDown size={19} className={`shrink-0 text-slate-400 transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && <div className="border-t border-slate-100 p-4">{children}</div>}
    </section>
  );
}

export default function ParentDashboard({
  profile,
  policy,
  dayType,
  todayKey,
  dailyLimit,
  baseDailyLimit,
  todaySpent,
  todayAvailable,
  earnedMinutesToday,
  earnBonusCap,
  parentBonusToday,
  testTimerSeconds,
  childStatus,
  detectedApplications,
  detectedApplicationsScannedAt,
  pendingRequests,
  recentEvents,
  earnTasks,
  spendTasks,
  syncStatus,
  onOpenChild,
  onApplyPreset,
  onUpdatePolicy,
  onUpdateProfile,
  onSetDayType,
  onResolveRequest,
  onAddTask,
  onEditTask,
  onDeleteTask,
  onChangePIN,
  onSetTestTimerSeconds,
  onSetAvailableMinutes,
  onSetApplicationProtection,
  onSendTestAlert,
  onReset,
}) {
  const [customSite, setCustomSite] = useState('');
  const [customSiteError, setCustomSiteError] = useState('');
  const [alertsOpen, setAlertsOpen] = useState(false);
  const alertEvents = useMemo(() => getParentAlertEvents(recentEvents), [recentEvents]);
  const [alertsEnabled, setAlertsEnabled] = useState(() => (
    window.localStorage.getItem(PARENT_ALERTS_ENABLED_KEY) === 'true'
  ));
  const [notificationPermission, setNotificationPermission] = useState(() => (
    'Notification' in window ? window.Notification.permission : 'unsupported'
  ));
  const [alertsReadAt, setAlertsReadAt] = useState(() => {
    const savedReadAt = Number(window.localStorage.getItem(PARENT_ALERTS_READ_AT_KEY));
    if (savedReadAt > 0) return savedReadAt;
    const initialReadAt = Number(alertEvents[0]?.createdAt) || Date.now();
    window.localStorage.setItem(PARENT_ALERTS_READ_AT_KEY, String(initialReadAt));
    return initialReadAt;
  });
  const lastObservedAlertId = useRef(alertEvents[0]?.id || null);
  const mountedAt = useRef(Date.now());
  const previousSyncStatus = useRef(syncStatus);
  const unreadAlerts = useMemo(
    () => getUnreadParentAlerts(alertEvents, alertsReadAt),
    [alertEvents, alertsReadAt],
  );
  const unreadCount = unreadAlerts.length + (syncStatus === 'disconnected' ? 1 : 0);
  const latestCriticalAlert = unreadAlerts.find((event) => event.type === 'blocked');
  const pendingRequest = pendingRequests.find((request) => request.status === 'pending');
  const statusText = childStatus.kind === 'playing'
    ? `Playing ${childStatus.taskTitle}`
    : childStatus.kind === 'earning'
      ? `Working on ${childStatus.taskTitle}`
      : 'Not in a timer';

  const changeLimit = (field, value) => onUpdatePolicy({
    id: 'custom',
    name: 'Custom',
    [field]: Number(value),
  });
  const restrictedDomains = new Set(policy.restrictedDomains || []);
  const builtInDomains = new Set(WEB_RESTRICTION_OPTIONS.map((item) => item.domain));
  const customDomains = [...restrictedDomains].filter((domain) => !builtInDomains.has(domain));
  const blockedBundleIdentifiers = new Set(policy.blockedBundleIdentifiers || []);
  const toggleRestrictedDomain = (domain) => {
    const nextDomains = new Set(restrictedDomains);
    if (nextDomains.has(domain)) nextDomains.delete(domain);
    else nextDomains.add(domain);
    onUpdatePolicy({ restrictedDomains: [...nextDomains].sort() });
  };
  const addCustomSite = (event) => {
    event.preventDefault();
    const domain = normalizeDomainInput(customSite);
    if (!domain) {
      setCustomSiteError('Enter a valid website, such as example.com.');
      return;
    }
    onUpdatePolicy({ restrictedDomains: [...new Set([...restrictedDomains, domain])].sort() });
    setCustomSite('');
    setCustomSiteError('');
  };
  const syncLabel = syncStatus === 'linked'
    ? 'Mac child linked · one shared state'
    : syncStatus === 'disconnected'
      ? 'Mac child not linked'
      : 'Connecting to Mac child…';

  const showBrowserAlert = useCallback((event) => {
    if (!event || !alertsEnabled || notificationPermission !== 'granted') return;
    const metadata = getParentAlertMetadata(event);
    try {
      new window.Notification(metadata.browserTitle, {
        body: event.message,
        tag: event.id,
        silent: metadata.level === 'info' || metadata.level === 'positive',
      });
      if ((metadata.level === 'critical' || metadata.level === 'action') && navigator.vibrate) {
        navigator.vibrate(metadata.level === 'critical' ? [250, 120, 250] : [180, 100, 180]);
      }
    } catch {
      // The in-app alert remains available when a browser blocks system notifications.
    }
  }, [alertsEnabled, notificationPermission]);

  useEffect(() => {
    const newestAlertId = alertEvents[0]?.id || null;
    if (!newestAlertId || newestAlertId === lastObservedAlertId.current) return;
    const previousIndex = alertEvents.findIndex((event) => event.id === lastObservedAlertId.current);
    const newlyArrived = previousIndex > 0 ? alertEvents.slice(0, previousIndex) : [alertEvents[0]];
    lastObservedAlertId.current = newestAlertId;
    const browserAlert = pickBrowserAlert(
      newlyArrived.filter((event) => Number(event.createdAt) >= mountedAt.current - 1_500),
    );
    showBrowserAlert(browserAlert);
  }, [alertEvents, showBrowserAlert]);

  useEffect(() => {
    const wasLinked = previousSyncStatus.current === 'linked';
    previousSyncStatus.current = syncStatus;
    if (!wasLinked || syncStatus !== 'disconnected') return;
    showBrowserAlert({
      id: `mac-offline-${Date.now()}`,
      type: 'offline',
      message: `${profile.childName}’s Mac is no longer reporting to the parent app.`,
    });
  }, [profile.childName, showBrowserAlert, syncStatus]);

  const enableBrowserAlerts = async () => {
    if (!('Notification' in window)) {
      setNotificationPermission('unsupported');
      return;
    }
    const permission = await window.Notification.requestPermission();
    setNotificationPermission(permission);
    const enabled = permission === 'granted';
    setAlertsEnabled(enabled);
    window.localStorage.setItem(PARENT_ALERTS_ENABLED_KEY, String(enabled));
    if (enabled) {
      new window.Notification('TimeBoxer alerts are on', {
        body: `This browser can now show ${profile.childName}’s requests and blocked attempts while the page is running.`,
        tag: 'timeboxer-alerts-enabled',
      });
    }
  };

  const disableBrowserAlerts = () => {
    setAlertsEnabled(false);
    window.localStorage.setItem(PARENT_ALERTS_ENABLED_KEY, 'false');
  };

  const markAllAlertsRead = () => {
    const readAt = Math.max(Date.now(), Number(alertEvents[0]?.createdAt) || 0);
    setAlertsReadAt(readAt);
    window.localStorage.setItem(PARENT_ALERTS_READ_AT_KEY, String(readAt));
  };

  return (
    <div className="min-h-[100dvh] bg-slate-200/70 text-slate-950">
      <div className="mx-auto min-h-[100dvh] w-full max-w-[430px] bg-[#f8faf8] shadow-2xl shadow-slate-900/10">
        <header className="sticky top-0 z-20 border-b border-slate-200/80 bg-white/95 backdrop-blur">
        <div className="flex items-center justify-between px-4 py-4">
          <div><BrandLogo compact /><div className="mt-1 pl-11 text-[11px] text-slate-400">Parent app</div></div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => setAlertsOpen(true)}
              className="relative rounded-xl border border-slate-200 bg-white p-2.5 text-slate-500 hover:border-emerald-300 hover:text-emerald-700"
              title="Parent alerts"
              aria-label={`Parent alerts${unreadCount > 0 ? `, ${unreadCount} unread` : ''}`}
            >
              <Bell size={18} />
              {unreadCount > 0 && (
                <span className="absolute -right-1.5 -top-1.5 flex min-h-5 min-w-5 items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-black text-white ring-2 ring-white">
                  {unreadCount > 9 ? '9+' : unreadCount}
                </span>
              )}
            </button>
            <button onClick={onChangePIN} className="rounded-xl border border-slate-200 bg-white p-2.5 text-slate-500 hover:border-emerald-300 hover:text-emerald-700" title="Change PIN"><Settings size={18} /></button>
            <button onClick={onOpenChild} className="rounded-xl border border-slate-200 bg-white p-2.5 text-slate-500 hover:border-emerald-300 hover:text-emerald-700" title="Child preview"><Smartphone size={18} /></button>
          </div>
        </div>
        </header>

      <main className="flex flex-col px-4 py-5">
        <div className="order-1 mb-5 flex flex-col justify-between gap-3">
          <div>
            <div className="text-sm font-bold text-emerald-600">Good to see you</div>
            <h1 className="mt-1 text-3xl font-black tracking-tight">{profile.childName}’s plan</h1>
          </div>
          <div className="flex items-center gap-2 text-sm text-slate-500">
            <span className={`h-2 w-2 rounded-full ${syncStatus === 'linked' ? 'bg-emerald-500' : syncStatus === 'disconnected' ? 'bg-red-500' : 'bg-amber-400'}`} />
            {syncLabel}
          </div>
        </div>

        <section className="order-2 grid gap-4">
          {syncStatus === 'disconnected' && (
            <div className="flex items-start gap-3 rounded-[24px] border border-red-200 bg-red-50 p-4 text-red-950 shadow-sm">
              <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-red-100 text-red-600"><WifiOff size={21} /></span>
              <div className="min-w-0 flex-1">
                <div className="text-xs font-black uppercase tracking-[0.14em] text-red-600">Connection alert</div>
                <div className="mt-1 font-black">{profile.childName}’s Mac is offline</div>
                <div className="mt-1 text-sm leading-relaxed text-red-700/70">New activity cannot reach this parent screen until the Mac reconnects.</div>
              </div>
            </div>
          )}

          {latestCriticalAlert && (
            <div className="rounded-[24px] border border-red-200 bg-red-50 p-4 text-red-950 shadow-sm">
              <div className="flex items-start gap-3">
                <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-red-100 text-red-600"><AlertTriangle size={21} /></span>
                <div className="min-w-0 flex-1">
                  <div className="text-xs font-black uppercase tracking-[0.14em] text-red-600">Blocked attempt</div>
                  <div className="mt-1 text-sm font-bold leading-relaxed">{latestCriticalAlert.message}</div>
                  <div className="mt-1 text-xs text-red-700/60">{formatEventTime(latestCriticalAlert.createdAt)}</div>
                </div>
              </div>
              <div className="mt-3 flex justify-end">
                <button type="button" onClick={markAllAlertsRead} className="rounded-xl bg-red-600 px-3 py-2 text-xs font-black text-white">Acknowledge</button>
              </div>
            </div>
          )}

          <div className="rounded-[24px] border border-slate-200 bg-white p-4 shadow-sm">
            <div className="flex items-start justify-between">
              <div>
                <div className="text-sm font-bold text-emerald-600">Child status</div>
                <div className="mt-2 text-2xl font-black">{statusText}</div>
                <div className="mt-2 text-sm text-slate-400">Last update {formatEventTime(childStatus.updatedAt)}</div>
              </div>
              <div className={`flex h-12 w-12 items-center justify-center rounded-2xl ${childStatus.kind === 'idle' ? 'bg-slate-100 text-slate-400' : 'bg-emerald-100 text-emerald-600'}`}><Activity size={23} /></div>
            </div>
            <div className="mt-7 grid grid-cols-3 gap-3">
              <div className="rounded-2xl bg-emerald-50 p-3"><div className="text-2xl font-black text-emerald-600">{todayAvailable}</div><div className="text-xs text-slate-400">Available</div></div>
              <div className="rounded-2xl bg-slate-50 p-3"><div className="text-2xl font-black">{todaySpent}</div><div className="text-xs text-slate-400">Used today</div></div>
              <div className="rounded-2xl bg-slate-50 p-3"><div className="text-2xl font-black">{earnedMinutesToday}<span className="text-sm text-slate-400"> / {earnBonusCap}</span></div><div className="text-xs text-slate-400">Earned bonus</div></div>
            </div>
          </div>

          <div className={`rounded-[24px] border p-4 ${pendingRequest ? 'border-emerald-200 bg-emerald-50' : 'border-slate-200 bg-white'}`}>
            <div className="flex items-center justify-between">
              <div className="text-sm font-black uppercase tracking-widest text-slate-400">Requests</div>
              <Gift size={20} className={pendingRequest ? 'text-emerald-600' : 'text-slate-300'} />
            </div>
            {pendingRequest ? (
              <div className="mt-5">
                <div className="text-xl font-black">{profile.childName} asked for {pendingRequest.minutes} more minutes</div>
                <div className="mt-2 text-sm text-slate-500">Approval adds a parent bonus for today only.</div>
                <div className="mt-5 flex gap-2">
                  <button onClick={() => onResolveRequest(pendingRequest.id, false)} className="flex flex-1 items-center justify-center gap-2 rounded-xl border border-slate-200 bg-white py-3 font-black text-slate-600"><X size={17} /> Decline</button>
                  <button onClick={() => onResolveRequest(pendingRequest.id, true)} className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[#35d532] py-3 font-black text-slate-950"><Check size={17} /> Approve</button>
                </div>
              </div>
            ) : (
              <div className="mt-8 text-center">
                <Check className="mx-auto text-emerald-500" size={30} />
                <div className="mt-3 font-black">No requests waiting</div>
                <div className="mt-1 text-sm text-slate-400">You’ll see extra-time requests here.</div>
              </div>
            )}
          </div>
        </section>

        <section className="order-3 mt-4">
          <div className="rounded-[24px] border border-slate-200 bg-white p-4">
            <div className="flex flex-col justify-between gap-3">
              <div>
                <div className="text-sm font-bold text-emerald-600">Today</div>
                <h2 className="mt-1 text-xl font-black">Choose the day type</h2>
              </div>
              <div className="flex rounded-2xl bg-slate-100 p-1">
                {Object.entries(DAY_TYPES).map(([id, label]) => (
                  <button key={id} data-testid={`day-type-${id}`} onClick={() => onSetDayType(todayKey, id)} className={`flex-1 rounded-xl px-3 py-2 text-xs font-black transition ${dayType === id ? 'bg-white text-slate-950 shadow-sm' : 'text-slate-400'}`}>{label}</button>
                ))}
              </div>
            </div>
            <div className="mt-6 flex items-center justify-between rounded-2xl bg-slate-50 p-5">
              <div>
                <div className="text-sm text-slate-400">Entertainment allowance</div>
                <div className="mt-1 text-3xl font-black">{dailyLimit} minutes</div>
                <div className="mt-2 text-xs text-slate-400">{baseDailyLimit} base + {earnedMinutesToday} earned{parentBonusToday > 0 ? ` + ${parentBonusToday} parent` : ''}</div>
              </div>
              <Clock3 size={28} className="text-emerald-600" />
            </div>
          </div>

        </section>

        <AccordionSection
          icon={Settings}
          eyebrow="Set once"
          title="Child profile"
          description="Name, age and bedtime protection."
          badge={`${profile.age} yrs`}
          className="order-9 mt-4"
        >
          <div className="grid grid-cols-2 gap-3">
            <label><span className="text-xs font-bold text-slate-400">Name</span><input value={profile.childName} onChange={(event) => onUpdateProfile({ childName: event.target.value })} className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2.5 font-bold outline-none focus:border-emerald-500" /></label>
            <label><span className="text-xs font-bold text-slate-400">Age</span><input type="number" min="5" max="17" value={profile.age} onChange={(event) => onUpdateProfile({ age: Number(event.target.value) })} className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2.5 font-bold outline-none focus:border-emerald-500" /></label>
            <label className="col-span-2"><span className="text-xs font-bold text-slate-400">Bedtime</span><input type="time" value={profile.bedtime} onChange={(event) => onUpdateProfile({ bedtime: event.target.value })} className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2.5 font-bold outline-none focus:border-emerald-500" /></label>
          </div>
        </AccordionSection>

        <AccordionSection
          icon={Gauge}
          eyebrow="Advanced"
          title="Testing tools"
          description="Adjust time without waiting during testing."
          badge={testTimerSeconds > 0 ? `${testTimerSeconds}s` : 'Real time'}
          className="order-10 mt-4"
        >
          <div data-testid="testing-tools" className="grid gap-4">
            <label className="rounded-2xl border border-emerald-100 bg-white p-4">
              <span className="text-xs font-bold text-slate-500">Earned bonus today</span>
              <div className="mt-2 flex items-center gap-2">
                <input
                  aria-label="Earned bonus today"
                  type="number"
                  min="0"
                  max={earnBonusCap}
                  value={earnedMinutesToday}
                  onChange={(event) => onSetAvailableMinutes(event.target.value)}
                  className="min-w-0 flex-1 bg-transparent text-3xl font-black outline-none"
                />
                <span className="text-sm font-bold text-slate-400">min</span>
              </div>
              <div className="mt-2 text-xs text-slate-400">Today’s earnable bonus cap is {earnBonusCap} min.</div>
            </label>

            <div className="rounded-2xl border border-emerald-100 bg-white p-4">
              <label className="text-xs font-bold text-slate-500" htmlFor="quick-test-seconds">Countdown length</label>
              <div className="mt-2 flex items-center gap-2">
                <input
                  id="quick-test-seconds"
                  aria-label="Quick test seconds"
                  type="number"
                  min="0"
                  max="300"
                  value={testTimerSeconds}
                  onChange={(event) => onSetTestTimerSeconds(event.target.value)}
                  className="min-w-0 flex-1 bg-transparent text-3xl font-black outline-none"
                />
                <span className="text-sm font-bold text-slate-400">sec</span>
              </div>
              <div className="mt-3 flex flex-wrap gap-2">
                {[
                  [0, 'Real time'],
                  [10, '10 sec'],
                  [30, '30 sec'],
                  [60, '60 sec'],
                ].map(([seconds, label]) => (
                  <button
                    key={seconds}
                    type="button"
                    onClick={() => onSetTestTimerSeconds(seconds)}
                    className={`rounded-xl px-3 py-2 text-xs font-black ${testTimerSeconds === seconds ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-emerald-100'}`}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>
            <button type="button" onClick={onSendTestAlert} className="flex items-center justify-center gap-2 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-black text-red-700">
              <AlertTriangle size={17} /> Send test blocked alert
            </button>
          </div>
        </AccordionSection>

        <div className="order-5 mt-7 px-1">
          <div className="text-xs font-black uppercase tracking-[0.18em] text-emerald-600">Settings</div>
          <div className="mt-1 text-sm text-slate-400">Open a category only when you need to change it.</div>
        </div>

        <AccordionSection
          icon={Clock3}
          eyebrow="Set once"
          title="Screen time plan"
          description="Weekly limits, earn caps and protected apps or websites."
          badge={policy.name}
          className="order-6 mt-4"
        >
          <div className="grid gap-3">
            {Object.values(POLICY_PRESETS).map((preset) => (
              <button key={preset.id} onClick={() => onApplyPreset(preset.id)} className={`rounded-2xl border p-4 text-left transition ${policy.id === preset.id ? 'border-emerald-500 bg-emerald-50 ring-2 ring-emerald-100' : 'border-slate-200 hover:border-emerald-300'}`}>
                <div className="flex items-center justify-between"><strong>{preset.name}</strong>{policy.id === preset.id && <Check size={18} className="text-emerald-600" />}</div>
                <div className="mt-1 text-sm text-slate-400">Up to {getMaximumDailyLimit(preset, 'school')}m school · {getMaximumDailyLimit(preset, 'weekend')}m weekend · {getMaximumDailyLimit(preset, 'holiday')}m holiday</div>
              </button>
            ))}
          </div>

          <div className="mt-6 text-xs font-black uppercase tracking-[0.16em] text-slate-400">Base allowance</div>
          <div className="mt-3 grid grid-cols-3 gap-2">
            {[
              ['schoolLimit', 'School day'],
              ['weekendLimit', 'Weekend'],
              ['holidayLimit', 'Holiday'],
            ].map(([field, label]) => (
              <label key={field} className="rounded-2xl bg-slate-50 p-3">
                <span className="text-xs font-bold text-slate-400">{label}</span>
                <div className="mt-1 flex items-center gap-1"><input type="number" min="0" max="120" value={policy[field]} onChange={(event) => changeLimit(field, event.target.value)} className="w-full bg-transparent text-2xl font-black outline-none" /><span className="text-sm font-bold text-slate-400">min</span></div>
              </label>
            ))}
          </div>

          <div className="mt-5 text-xs font-black uppercase tracking-[0.16em] text-slate-400">Earnable bonus cap</div>
          <div className="mt-3 grid grid-cols-3 gap-2">
            {[
              ['schoolEarnCapMinutes', 'School day'],
              ['weekendEarnCapMinutes', 'Weekend'],
              ['holidayEarnCapMinutes', 'Holiday'],
            ].map(([field, label]) => (
              <label key={field} className="rounded-2xl bg-emerald-50/70 p-3">
                <span className="text-xs font-bold text-emerald-700">{label}</span>
                <div className="mt-1 flex items-center gap-1"><input type="number" min="0" max="60" value={policy[field]} onChange={(event) => changeLimit(field, event.target.value)} className="w-full bg-transparent text-2xl font-black outline-none" /><span className="text-sm font-bold text-slate-400">min</span></div>
              </label>
            ))}
          </div>

          <label className="mt-4 flex max-w-xs items-center justify-between gap-4 rounded-2xl bg-slate-50 p-3">
            <span><span className="block text-xs font-bold text-slate-400">Max session</span><span className="text-xs text-slate-400">Longest play session</span></span>
            <span className="flex items-center gap-1"><input type="number" min="5" max="60" value={policy.maxSessionMinutes} onChange={(event) => changeLimit('maxSessionMinutes', event.target.value)} className="w-16 bg-transparent text-right text-2xl font-black outline-none" /><span className="text-sm font-bold text-slate-400">min</span></span>
          </label>

          <div className="mt-5 grid gap-3 text-sm">
            <div className="flex items-center gap-3 rounded-2xl border border-slate-200 p-4"><Moon className="text-indigo-500" size={20} /><div><strong>Bedtime protection</strong><span className="block text-slate-400">Stops 60 min before bed</span></div></div>
            <div className="flex items-center gap-3 rounded-2xl border border-slate-200 p-4"><Clock3 className="text-amber-500" size={20} /><div><strong>Eye break</strong><span className="block text-slate-400">10 min after long play</span></div></div>
            <div className="flex items-center gap-3 rounded-2xl border border-slate-200 p-4"><ShieldCheck className="text-emerald-500" size={20} /><div><strong>Health ceiling</strong><span className="block text-slate-400">Never above 120 min</span></div></div>
          </div>
        </AccordionSection>

        <AccordionSection
          icon={ShieldCheck}
          eyebrow="Set once"
          title="App & website protection"
          description="Choose what the child Mac blocks outside Play time."
          badge={`${blockedBundleIdentifiers.size} apps`}
          className="order-7 mt-4"
        >
          <AccordionSection
            icon={Globe2}
            eyebrow="Protection list"
            title="Websites"
            description="Video and web-game domains."
            badge={`${restrictedDomains.size} sites`}
          >
            <p className="text-sm leading-relaxed text-slate-500">Selected sites are blocked in Safari and Chrome unless a Play timer is running.</p>
            {['Video', 'Web games'].map((group) => (
              <div key={group} className="mt-4">
                <div className="text-xs font-black uppercase tracking-[0.14em] text-slate-400">{group}</div>
                <div className="mt-2 flex flex-wrap gap-2">
                  {WEB_RESTRICTION_OPTIONS.filter((item) => item.group === group).map((item) => {
                    const selected = restrictedDomains.has(item.domain);
                    return (
                      <button
                        key={item.domain}
                        type="button"
                        aria-pressed={selected}
                        onClick={() => toggleRestrictedDomain(item.domain)}
                        className={`rounded-xl border px-3 py-2 text-xs font-black transition ${selected ? 'border-emerald-300 bg-emerald-50 text-emerald-700' : 'border-slate-200 bg-white text-slate-400'}`}
                      >
                        {selected ? '✓ ' : ''}{item.label}
                      </button>
                    );
                  })}
                </div>
              </div>
            ))}

            <div className="mt-5 border-t border-slate-100 pt-4">
              <div className="flex items-center gap-2 text-xs font-black uppercase tracking-[0.14em] text-slate-400"><Globe2 size={15} /> Custom websites</div>
              <form onSubmit={addCustomSite} className="mt-3 flex gap-2">
                <input
                  value={customSite}
                  onChange={(event) => {
                    setCustomSite(event.target.value);
                    if (customSiteError) setCustomSiteError('');
                  }}
                  aria-label="Custom website"
                  inputMode="url"
                  placeholder="example.com"
                  className="min-w-0 flex-1 rounded-xl border border-slate-200 px-3 py-2.5 text-sm font-semibold outline-none focus:border-emerald-500"
                />
                <button type="submit" className="rounded-xl bg-slate-950 px-4 py-2.5 text-sm font-black text-white">Add</button>
              </form>
              {customSiteError && <div className="mt-2 text-xs font-bold text-red-500">{customSiteError}</div>}
              {customDomains.length > 0 && (
                <div className="mt-3 flex flex-wrap gap-2">
                  {customDomains.map((domain) => (
                    <button key={domain} type="button" onClick={() => toggleRestrictedDomain(domain)} className="flex items-center gap-1 rounded-xl border border-emerald-300 bg-emerald-50 px-3 py-2 text-xs font-black text-emerald-700">
                      {domain} <X size={13} />
                    </button>
                  ))}
                </div>
              )}
              <p className="mt-2 text-xs leading-relaxed text-slate-400">Paste a full link or enter a domain. TimeBoxer saves only the website domain.</p>
            </div>
          </AccordionSection>

          <AccordionSection
            icon={AppWindow}
            eyebrow="Detected on Mac"
            title="Applications"
            description="Select installed apps to protect."
            badge={`${detectedApplications.length} found`}
            className="mt-3"
          >
            <p className="text-sm leading-relaxed text-slate-500">Detected on {profile.childName}’s Mac. Recommended entertainment apps start protected; a parent can change each one.</p>
            {detectedApplications.length === 0 ? (
              <div className="mt-4 rounded-2xl bg-slate-50 p-4 text-sm text-slate-400">
                Connect the child Mac to load its installed apps.
              </div>
            ) : (
              <div className="mt-4 space-y-2">
                {detectedApplications.map((application) => {
                  const protectedApp = blockedBundleIdentifiers.has(application.bundleIdentifier);
                  return (
                    <div key={application.bundleIdentifier} className="flex items-center gap-3 rounded-2xl bg-slate-50 p-3">
                      <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ${application.recommended ? 'bg-violet-100 text-violet-600' : 'bg-white text-slate-400'}`}>
                        {application.recommended ? <Gamepad2 size={18} /> : <AppWindow size={18} />}
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-sm font-black">{application.name}</div>
                        <div className="truncate text-[11px] text-slate-400">{application.recommended ? 'Entertainment suggested' : 'Not protected by default'}</div>
                      </div>
                      <button
                        type="button"
                        role="switch"
                        aria-checked={protectedApp}
                        aria-label={`Protect ${application.name}`}
                        onClick={() => onSetApplicationProtection(application.bundleIdentifier, !protectedApp)}
                        className={`relative h-7 w-12 shrink-0 rounded-full transition ${protectedApp ? 'bg-[#35d532]' : 'bg-slate-200'}`}
                      >
                        <span className={`absolute top-1 h-5 w-5 rounded-full bg-white shadow-sm transition ${protectedApp ? 'left-6' : 'left-1'}`} />
                      </button>
                    </div>
                  );
                })}
              </div>
            )}
            {detectedApplicationsScannedAt > 0 && (
              <div className="mt-3 text-xs text-slate-400">Last checked {formatEventTime(detectedApplicationsScannedAt)} · refreshes automatically</div>
            )}
          </AccordionSection>
        </AccordionSection>

        <section className="contents">
          <AccordionSection
            icon={Gift}
            eyebrow="Set occasionally"
            title="Activities & rewards"
            description="Choose what earns time and what uses it."
            badge={`${earnTasks.length + spendTasks.length} items`}
            className="order-8 mt-4"
          >
            <div className="mb-4 flex justify-end"><button onClick={() => onAddTask('earn')} className="flex items-center gap-2 rounded-xl bg-[#35d532] px-3 py-2 text-sm font-black text-slate-950"><Plus size={16} /> Add earn</button></div>
            <div className="space-y-2">
              {[...earnTasks.map((task) => ({ ...task, kind: 'earn' })), ...spendTasks.map((task) => ({ ...task, kind: 'spend' }))].map((task) => (
                <div key={task.id} className="flex items-center gap-3 rounded-2xl bg-slate-50 p-3">
                  <div className={`flex h-10 w-10 items-center justify-center rounded-xl ${task.kind === 'earn' ? 'bg-emerald-100 text-emerald-600' : 'bg-violet-100 text-violet-600'}`}>{task.kind === 'earn' ? <Gift size={18} /> : <Gamepad2 size={18} />}</div>
                  <div className="min-w-0 flex-1"><div className="truncate font-bold">{task.title}</div><div className="text-xs text-slate-400">{task.duration} min · {task.kind === 'earn' ? `+${task.reward} bonus` : 'uses today’s allowance'}</div></div>
                  <button onClick={() => onEditTask(task, task.kind)} className="rounded-lg p-2 text-slate-400 hover:bg-white hover:text-slate-950"><Pencil size={16} /></button>
                  <button onClick={() => onDeleteTask(task.id, task.kind)} className="rounded-lg p-2 text-slate-400 hover:bg-white hover:text-red-500"><Trash2 size={16} /></button>
                </div>
              ))}
            </div>
            <button onClick={() => onAddTask('spend')} className="mt-3 flex items-center gap-2 text-sm font-black text-emerald-600"><Plus size={16} /> Add entertainment</button>
          </AccordionSection>

          <div className="order-4 mt-4 rounded-[24px] border border-slate-200 bg-white p-4 shadow-sm">
            <div className="flex items-center justify-between"><div><div className="text-sm font-bold text-emerald-600">Live activity</div><h2 className="mt-1 text-xl font-black">Recent</h2></div><ChevronRight size={20} className="text-slate-300" /></div>
            <div className="mt-5 space-y-4">
              {recentEvents.length === 0 && <div className="rounded-2xl bg-slate-50 p-5 text-center text-sm text-slate-400">Activity will appear here.</div>}
              {recentEvents.slice(0, 4).map((event) => (
                <div key={event.id} className="flex gap-3">
                  <div className="mt-1 h-2 w-2 shrink-0 rounded-full bg-emerald-500" />
                  <div className="min-w-0 flex-1"><div className="text-sm font-semibold text-slate-700">{event.message}</div><div className="mt-0.5 text-xs text-slate-400">{formatEventTime(event.createdAt)}</div></div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <div className="order-[11] mt-6 flex justify-end">
          <button onClick={onReset} className="flex items-center gap-2 text-sm font-bold text-slate-400 hover:text-red-500"><RotateCcw size={16} /> Reset time data</button>
        </div>
      </main>

      {alertsOpen && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-slate-950/45 p-0 backdrop-blur-sm sm:p-4">
          <button type="button" aria-label="Close parent alerts" onClick={() => setAlertsOpen(false)} className="absolute inset-0" />
          <section role="dialog" aria-modal="true" aria-labelledby="parent-alerts-title" className="relative z-10 max-h-[88dvh] w-full max-w-[430px] overflow-y-auto rounded-t-[30px] bg-[#f8faf8] shadow-2xl sm:rounded-[30px]">
            <div className="sticky top-0 z-10 flex items-center justify-between border-b border-slate-200 bg-white/95 px-5 py-4 backdrop-blur">
              <div className="flex items-center gap-3">
                <span className="flex h-10 w-10 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-600"><Bell size={20} /></span>
                <div>
                  <h2 id="parent-alerts-title" className="text-lg font-black">Parent alerts</h2>
                  <div className="text-xs text-slate-400">{unreadCount > 0 ? `${unreadCount} need attention` : 'You’re up to date'}</div>
                </div>
              </div>
              <button type="button" aria-label="Close" onClick={() => setAlertsOpen(false)} className="rounded-xl bg-slate-100 p-2 text-slate-500"><X size={18} /></button>
            </div>

            <div className="space-y-4 p-4">
              <div className="rounded-[22px] border border-slate-200 bg-white p-4 shadow-sm">
                <div className="flex items-start gap-3">
                  <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl ${alertsEnabled && notificationPermission === 'granted' ? 'bg-emerald-100 text-emerald-600' : 'bg-slate-100 text-slate-500'}`}><Bell size={19} /></span>
                  <div className="min-w-0 flex-1">
                    <div className="font-black">Browser alerts</div>
                    <p className="mt-1 text-xs leading-relaxed text-slate-400">Shows requests and blocked attempts while this parent page is running, including supported background tabs.</p>
                  </div>
                </div>
                {notificationPermission === 'unsupported' ? (
                  <div className="mt-3 rounded-xl bg-amber-50 p-3 text-xs font-bold leading-relaxed text-amber-700">This browser cannot show system alerts yet. In-app alerts still work.</div>
                ) : notificationPermission === 'denied' ? (
                  <div className="mt-3 rounded-xl bg-red-50 p-3 text-xs font-bold leading-relaxed text-red-700">Notifications are blocked in this browser’s settings. In-app alerts still work.</div>
                ) : alertsEnabled && notificationPermission === 'granted' ? (
                  <div className="mt-3 flex items-center justify-between rounded-xl bg-emerald-50 px-3 py-2.5">
                    <span className="text-xs font-black text-emerald-700">Alerts enabled</span>
                    <button type="button" onClick={disableBrowserAlerts} className="text-xs font-black text-slate-500">Turn off</button>
                  </div>
                ) : (
                  <button type="button" onClick={enableBrowserAlerts} className="mt-3 w-full rounded-xl bg-slate-950 px-4 py-3 text-sm font-black text-white">Enable browser alerts</button>
                )}
                <p className="mt-3 text-[11px] leading-relaxed text-slate-400">Notifications after the app is fully closed will be added with the iPhone app and cloud push service.</p>
              </div>

              {syncStatus === 'disconnected' && (
                <div className="flex items-start gap-3 rounded-[22px] border border-red-200 bg-red-50 p-4">
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl bg-red-100 text-red-600"><WifiOff size={19} /></span>
                  <div><div className="font-black text-red-950">Mac child offline</div><div className="mt-1 text-xs leading-relaxed text-red-700/70">Check that TimeBoxer is running on {profile.childName}’s Mac.</div></div>
                </div>
              )}

              <div className="flex items-end justify-between px-1">
                <div><div className="text-xs font-black uppercase tracking-[0.14em] text-emerald-600">Activity alerts</div><div className="mt-1 text-sm text-slate-400">Newest first</div></div>
                {unreadAlerts.length > 0 && <button type="button" onClick={markAllAlertsRead} className="text-xs font-black text-emerald-700">Mark all read</button>}
              </div>

              <div className="space-y-2">
                {alertEvents.length === 0 && (
                  <div className="rounded-[22px] border border-slate-200 bg-white p-6 text-center text-sm text-slate-400">Requests and important child activity will appear here.</div>
                )}
                {alertEvents.slice(0, 12).map((event) => {
                  const metadata = getParentAlertMetadata(event);
                  const styles = alertStyle[metadata.level] || alertStyle.info;
                  const isUnread = Number(event.createdAt) > alertsReadAt;
                  return (
                    <div key={event.id} className={`rounded-[22px] border p-4 ${styles.card}`}>
                      <div className="flex items-start gap-3">
                        <span className={`mt-1 h-2.5 w-2.5 shrink-0 rounded-full ${isUnread ? styles.dot : 'bg-slate-300'}`} />
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center justify-between gap-2"><div className="text-sm font-black">{metadata.title}</div><div className="shrink-0 text-[11px] text-slate-400">{formatEventTime(event.createdAt)}</div></div>
                          <div className="mt-1 text-sm font-semibold leading-relaxed text-slate-600">{event.message}</div>
                          {event.type === 'request' && pendingRequest && (
                            <div className="mt-3 grid grid-cols-2 gap-2">
                              <button type="button" onClick={() => onResolveRequest(pendingRequest.id, false)} className="rounded-xl border border-slate-200 bg-white py-2.5 text-xs font-black text-slate-600">Decline</button>
                              <button type="button" onClick={() => onResolveRequest(pendingRequest.id, true)} className="rounded-xl bg-[#35d532] py-2.5 text-xs font-black text-slate-950">Approve +{pendingRequest.minutes}</button>
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </section>
        </div>
      )}
      </div>
    </div>
  );
}
