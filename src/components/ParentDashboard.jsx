import {
  Activity,
  Check,
  ChevronRight,
  Clock3,
  ExternalLink,
  Gamepad2,
  Gauge,
  Gift,
  Moon,
  Pencil,
  Plus,
  RotateCcw,
  Settings,
  ShieldCheck,
  Trash2,
  X,
} from 'lucide-react';
import { DAY_TYPES, getMaximumDailyLimit, POLICY_PRESETS } from '../policy.js';
import BrandLogo from './BrandLogo.jsx';

const formatEventTime = (timestamp) => new Intl.DateTimeFormat('en-NZ', {
  hour: 'numeric',
  minute: '2-digit',
}).format(new Date(timestamp));

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
  pendingRequests,
  recentEvents,
  earnTasks,
  spendTasks,
  syncStatus,
  onOpenChild,
  onOpenChildTab,
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
  onReset,
}) {
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
  const syncLabel = syncStatus === 'linked'
    ? 'Mac child linked · one shared state'
    : syncStatus === 'disconnected'
      ? 'Mac child not linked'
      : 'Connecting to Mac child…';

  return (
    <div className="min-h-[100dvh] bg-[#f8faf8] text-slate-950">
      <header className="border-b border-slate-200/80 bg-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-5 py-5">
          <div><BrandLogo compact /><div className="mt-1 pl-11 text-xs text-slate-400">Parent dashboard</div></div>
          <div className="flex items-center gap-2">
            <button onClick={onChangePIN} className="rounded-xl border border-slate-200 bg-white p-2.5 text-slate-500 hover:border-emerald-300 hover:text-emerald-700" title="Change PIN"><Settings size={18} /></button>
            <button onClick={onOpenChild} className="rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm font-black hover:border-emerald-300 hover:text-emerald-700">Child view</button>
            <button onClick={onOpenChildTab} className="hidden items-center gap-2 rounded-xl bg-[#35d532] px-4 py-2.5 text-sm font-black text-slate-950 hover:bg-emerald-400 sm:flex">Open linked tab <ExternalLink size={16} /></button>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-5 py-7">
        <div className="mb-7 flex flex-col justify-between gap-3 sm:flex-row sm:items-end">
          <div>
            <div className="text-sm font-bold text-emerald-600">Good to see you</div>
            <h1 className="mt-1 text-3xl font-black tracking-tight">{profile.childName}’s plan</h1>
          </div>
          <div className="flex items-center gap-2 text-sm text-slate-500">
            <span className={`h-2 w-2 rounded-full ${syncStatus === 'linked' ? 'bg-emerald-500' : syncStatus === 'disconnected' ? 'bg-red-500' : 'bg-amber-400'}`} />
            {syncLabel}
          </div>
        </div>

        <section className="grid gap-4 lg:grid-cols-[1.35fr_1fr]">
          <div className="rounded-[28px] border border-slate-200 bg-white p-6 shadow-sm">
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

          <div className={`rounded-[28px] border p-6 ${pendingRequest ? 'border-emerald-200 bg-emerald-50' : 'border-slate-200 bg-white'}`}>
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

        <section className="mt-5 grid gap-5 lg:grid-cols-[1.35fr_1fr]">
          <div className="rounded-[28px] border border-slate-200 bg-white p-6">
            <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
              <div>
                <div className="text-sm font-bold text-emerald-600">Today</div>
                <h2 className="mt-1 text-xl font-black">Choose the day type</h2>
              </div>
              <div className="flex rounded-2xl bg-slate-100 p-1">
                {Object.entries(DAY_TYPES).map(([id, label]) => (
                  <button key={id} data-testid={`day-type-${id}`} onClick={() => onSetDayType(todayKey, id)} className={`rounded-xl px-3 py-2 text-xs font-black transition sm:px-4 ${dayType === id ? 'bg-white text-slate-950 shadow-sm' : 'text-slate-400'}`}>{label}</button>
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

          <div className="rounded-[28px] border border-slate-200 bg-white p-6">
            <div className="text-sm font-bold text-emerald-600">Child details</div>
            <div className="mt-4 grid grid-cols-2 gap-3">
              <label><span className="text-xs font-bold text-slate-400">Name</span><input value={profile.childName} onChange={(event) => onUpdateProfile({ childName: event.target.value })} className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2.5 font-bold outline-none focus:border-emerald-500" /></label>
              <label><span className="text-xs font-bold text-slate-400">Age</span><input type="number" min="5" max="17" value={profile.age} onChange={(event) => onUpdateProfile({ age: Number(event.target.value) })} className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2.5 font-bold outline-none focus:border-emerald-500" /></label>
              <label className="col-span-2"><span className="text-xs font-bold text-slate-400">Bedtime</span><input type="time" value={profile.bedtime} onChange={(event) => onUpdateProfile({ bedtime: event.target.value })} className="mt-1 w-full rounded-xl border border-slate-200 px-3 py-2.5 font-bold outline-none focus:border-emerald-500" /></label>
            </div>
          </div>
        </section>

        <section data-testid="testing-tools" className="mt-5 rounded-[28px] border border-emerald-200 bg-emerald-50/60 p-6">
          <div className="flex flex-col justify-between gap-2 sm:flex-row sm:items-start">
            <div>
              <div className="flex items-center gap-2 text-sm font-bold text-emerald-700"><Gauge size={18} /> Parent-only testing tools</div>
              <h2 className="mt-1 text-xl font-black">Adjust time without waiting</h2>
              <p className="mt-1 text-sm text-slate-500">Quick countdown changes only the test speed. Real rewards and limits still apply.</p>
            </div>
            <div className={`rounded-full px-3 py-1.5 text-xs font-black ${testTimerSeconds > 0 ? 'bg-emerald-600 text-white' : 'bg-white text-slate-500'}`}>
              {testTimerSeconds > 0 ? `Quick test: ${testTimerSeconds}s` : 'Real time'}
            </div>
          </div>

          <div className="mt-5 grid gap-4 md:grid-cols-2">
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
          </div>
        </section>

        <section className="mt-5 rounded-[28px] border border-slate-200 bg-white p-6">
          <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-end">
            <div>
              <div className="text-sm font-bold text-emerald-600">Weekly plan</div>
              <h2 className="mt-1 text-xl font-black">Keep the rules simple</h2>
            </div>
            <div className="text-sm text-slate-400">Current: <strong className="text-slate-700">{policy.name}</strong></div>
          </div>

          <div className="mt-5 grid gap-3 md:grid-cols-3">
            {Object.values(POLICY_PRESETS).map((preset) => (
              <button key={preset.id} onClick={() => onApplyPreset(preset.id)} className={`rounded-2xl border p-4 text-left transition ${policy.id === preset.id ? 'border-emerald-500 bg-emerald-50 ring-2 ring-emerald-100' : 'border-slate-200 hover:border-emerald-300'}`}>
                <div className="flex items-center justify-between"><strong>{preset.name}</strong>{policy.id === preset.id && <Check size={18} className="text-emerald-600" />}</div>
                <div className="mt-1 text-sm text-slate-400">Up to {getMaximumDailyLimit(preset, 'school')}m school · {getMaximumDailyLimit(preset, 'weekend')}m weekend · {getMaximumDailyLimit(preset, 'holiday')}m holiday</div>
              </button>
            ))}
          </div>

          <div className="mt-6 text-xs font-black uppercase tracking-[0.16em] text-slate-400">Base allowance</div>
          <div className="mt-3 grid gap-3 sm:grid-cols-3">
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
          <div className="mt-3 grid gap-3 sm:grid-cols-3">
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

          <div className="mt-5 grid gap-3 text-sm sm:grid-cols-3">
            <div className="flex items-center gap-3 rounded-2xl border border-slate-200 p-4"><Moon className="text-indigo-500" size={20} /><div><strong>Bedtime protection</strong><span className="block text-slate-400">Stops 60 min before bed</span></div></div>
            <div className="flex items-center gap-3 rounded-2xl border border-slate-200 p-4"><Clock3 className="text-amber-500" size={20} /><div><strong>Eye break</strong><span className="block text-slate-400">10 min after long play</span></div></div>
            <div className="flex items-center gap-3 rounded-2xl border border-slate-200 p-4"><ShieldCheck className="text-emerald-500" size={20} /><div><strong>Health ceiling</strong><span className="block text-slate-400">Never above 120 min</span></div></div>
          </div>
        </section>

        <section className="mt-5 grid gap-5 lg:grid-cols-[1.35fr_1fr]">
          <div className="rounded-[28px] border border-slate-200 bg-white p-6">
            <div className="flex items-center justify-between"><div><div className="text-sm font-bold text-emerald-600">Routines</div><h2 className="mt-1 text-xl font-black">Activities</h2></div><button onClick={() => onAddTask('earn')} className="flex items-center gap-2 rounded-xl bg-[#35d532] px-3 py-2 text-sm font-black text-slate-950"><Plus size={16} /> Add earn</button></div>
            <div className="mt-5 space-y-2">
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
          </div>

          <div className="rounded-[28px] border border-slate-200 bg-white p-6">
            <div className="flex items-center justify-between"><div><div className="text-sm font-bold text-emerald-600">Live activity</div><h2 className="mt-1 text-xl font-black">Recent</h2></div><ChevronRight size={20} className="text-slate-300" /></div>
            <div className="mt-5 space-y-4">
              {recentEvents.length === 0 && <div className="rounded-2xl bg-slate-50 p-5 text-center text-sm text-slate-400">Activity will appear here.</div>}
              {recentEvents.slice(0, 6).map((event) => (
                <div key={event.id} className="flex gap-3">
                  <div className="mt-1 h-2 w-2 shrink-0 rounded-full bg-emerald-500" />
                  <div className="min-w-0 flex-1"><div className="text-sm font-semibold text-slate-700">{event.message}</div><div className="mt-0.5 text-xs text-slate-400">{formatEventTime(event.createdAt)}</div></div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <div className="mt-6 flex justify-end">
          <button onClick={onReset} className="flex items-center gap-2 text-sm font-bold text-slate-400 hover:text-red-500"><RotateCcw size={16} /> Reset time data</button>
        </div>
      </main>
    </div>
  );
}
