import { useState, useEffect, useCallback } from 'react';
import { useStore } from './store';
import Timer from './components/Timer';
import Onboarding from './components/Onboarding';
import { BookOpen, Dumbbell, Gamepad2, Tv, Battery, BatteryFull, Box, Pencil, Trash2, Star, Plus, Target, Lock, Settings } from 'lucide-react';

const ICON_MAP = {
  BookOpen, Dumbbell, Gamepad2, Tv, Star, Target
};

function App() {
  const { 
    availableMinutes, totalEarned, totalSpent, 
    earnTasks, spendTasks, 
    addEarnTask, updateEarnTask, deleteEarnTask,
    addSpendTask, updateSpendTask, deleteSpendTask,
    addMinutes, setDailyCap, dailyCap, todaySpent, lastSpentDate, cooldownUntil, recordSpend,
    parentPIN, setParentPIN, cooldownDuration, setCooldownDuration,
    hasSeenOnboarding, completeOnboarding
  } = useStore();
  
  const [activeTimer, setActiveTimer] = useState(null);
  const [now, setNow] = useState(Date.now());

  // Update "now" for realtime cooldown tracking
  useEffect(() => {
    const interval = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(interval);
  }, []);

  const todayStr = new Date().toISOString().split('T')[0];
  const actualTodaySpent = (lastSpentDate === todayStr) ? todaySpent : 0;
  
  // Cooldown logic
  const cooldownRemaining = cooldownUntil - now;
  const isCoolingDown = cooldownRemaining > 0;
  
  const formatCooldown = (ms) => {
    const totalSeconds = Math.ceil(ms / 1000);
    const m = Math.floor(totalSeconds / 60);
    const s = totalSeconds % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  };

  const handleTaskClick = (duration, reward) => {
    setActiveTimer({ mode: 'earn', duration, reward });
  };

  const handleSpendClick = (duration, cost) => {
    if (isCoolingDown) {
      alert("Eyes are cooling down! Please rest.");
      return;
    }
    if (actualTodaySpent + duration > dailyCap) {
      alert("Daily limit reached! No more screen time today.");
      return;
    }
    if (availableMinutes >= cost) {
      setActiveTimer({ mode: 'spend', duration, cost });
    } else {
      alert("Not enough time coins! Go earn some first.");
    }
  };

  const handleTimerComplete = useCallback((duration, extraMinutes = 0) => {
    if (activeTimer.mode === 'earn') {
      addMinutes(activeTimer.reward + extraMinutes);
      new Audio('https://assets.mixkit.co/active_storage/sfx/2013/2013-preview.mp3').play().catch(() => {});
    } else {
      // Spend mode complete
      recordSpend(duration, activeTimer.cost);
      new Audio('https://assets.mixkit.co/active_storage/sfx/995/995-preview.mp3').play().catch(() => {});
    }
    setActiveTimer(null);
  }, [activeTimer, addMinutes, recordSpend]);

  const handleTimerCancel = useCallback((playedMinutes = null) => {
    if (activeTimer.mode === 'spend' && playedMinutes !== null && playedMinutes > 0) {
      // Early exit: refund proportionally, but do NOT trigger cooldown
      const costPerMinute = activeTimer.cost / activeTimer.duration;
      const actualCost = Math.ceil(playedMinutes * costPerMinute);
      recordSpend(playedMinutes, actualCost, false);
    }
    setActiveTimer(null);
  }, [activeTimer, recordSpend]);

  const requirePIN = () => {
    const pin = window.prompt("家长锁：请输入密码 (Parent PIN to edit):");
    if (pin === parentPIN) return true;
    if (pin !== null) alert("密码错误 (Incorrect PIN)!");
    return false;
  };

  const handleEditDailyCap = () => {
    if (!requirePIN()) return;
    const newCap = window.prompt("Today's Limit (minutes):", dailyCap);
    if (!newCap) return;
    const parsed = parseInt(newCap, 10);
    if (!isNaN(parsed) && parsed >= 0) {
      setDailyCap(parsed);
    }
  };

  const handleEditCooldown = () => {
    if (!requirePIN()) return;
    const newCD = window.prompt("Eye Rest Cooldown (minutes):", cooldownDuration);
    if (!newCD) return;
    const parsed = parseInt(newCD, 10);
    if (!isNaN(parsed) && parsed >= 0) {
      setCooldownDuration(parsed);
    }
  };

  const handleChangePIN = () => {
    const current = window.prompt("请输入当前家长密码 (Current PIN):");
    if (current !== parentPIN) {
      if (current !== null) alert("密码错误 (Incorrect PIN)!");
      return;
    }
    const newPin = window.prompt("请输入新的密码 (New PIN):");
    if (newPin && newPin.trim().length > 0) {
      setParentPIN(newPin.trim());
      alert("密码修改成功 (PIN successfully updated)!");
    }
  };

  const promptEditTask = (task, type) => {
    if (!requirePIN()) return;
    const newName = window.prompt("Task Name:", task.title);
    if (newName === null) return;
    const newDuration = window.prompt("Duration (minutes):", task.duration);
    if (newDuration === null) return;
    const newReward = window.prompt(type === 'earn' ? "Reward (minutes):" : "Cost (minutes):", type === 'earn' ? task.reward : task.cost);
    if (newReward === null) return;

    const parsedDuration = parseInt(newDuration, 10);
    const parsedReward = parseInt(newReward, 10);

    if (!newName || isNaN(parsedDuration) || isNaN(parsedReward)) {
      alert("Invalid input!");
      return;
    }
    if (parsedDuration <= 0) {
      alert("Duration must be at least 1 minute!");
      return;
    }
    if (parsedDuration > 180) {
      alert("Duration cannot exceed 180 minutes!");
      return;
    }
    if (type === 'earn' && parsedReward > parsedDuration) {
      alert("Earn reward cannot exceed task duration! (reward ≤ duration)");
      return;
    }

    const updated = {
      ...task,
      title: newName,
      duration: parsedDuration,
      [type === 'earn' ? 'reward' : 'cost']: parsedReward
    };

    if (type === 'earn') updateEarnTask(task.id, updated);
    else updateSpendTask(task.id, updated);
  };

  const promptDeleteTask = (id, type) => {
    if (!requirePIN()) return;
    if (window.confirm("Delete this task?")) {
      if (type === 'earn') deleteEarnTask(id);
      else deleteSpendTask(id);
    }
  };

  const handleAddTask = (type) => {
    if (!requirePIN()) return;
    const newName = window.prompt("New Task Name:");
    if (!newName) return;
    const newDuration = window.prompt("Duration (minutes):", "30");
    if (!newDuration) return;
    const newReward = window.prompt(type === 'earn' ? "Reward (minutes):" : "Cost (minutes):", "30");
    if (!newReward) return;

    const parsedDuration = parseInt(newDuration, 10);
    const parsedReward = parseInt(newReward, 10);

    if (isNaN(parsedDuration) || isNaN(parsedReward)) {
      alert("Invalid duration or reward!");
      return;
    }
    if (parsedDuration <= 0) {
      alert("Duration must be at least 1 minute!");
      return;
    }
    if (parsedDuration > 180) {
      alert("Duration cannot exceed 180 minutes!");
      return;
    }
    if (type === 'earn' && parsedReward > parsedDuration) {
      alert("Earn reward cannot exceed task duration! (reward ≤ duration)");
      return;
    }

    const newTask = {
      id: `${type}-${Date.now()}`,
      title: newName,
      duration: parsedDuration,
      icon: 'Star',
    };
    
    if (type === 'earn') {
      newTask.reward = parsedReward;
      addEarnTask(newTask);
    } else {
      newTask.cost = parsedReward;
      addSpendTask(newTask);
    }
  };

  if (activeTimer) {
    return (
      <Timer 
        mode={activeTimer.mode} 
        duration={activeTimer.duration} 
        parentPIN={parentPIN}
        onComplete={handleTimerComplete}
        onCancel={handleTimerCancel}
      />
    );
  }

  return (
    <>
      {!hasSeenOnboarding && <Onboarding onComplete={completeOnboarding} />}
      <div className="min-h-[100dvh] md:h-[100dvh] p-3 md:p-6 max-w-6xl mx-auto flex flex-col font-sans w-full md:overflow-hidden relative">
        
        {/* Settings Gear */}
        <button onClick={handleChangePIN} className="fixed top-4 right-4 text-gray-500 hover:text-white p-2 rounded-full transition-colors bg-black/50 backdrop-blur-md border border-white/10 group z-50 shadow-lg">
          <Settings size={20} className="group-hover:rotate-90 transition-transform" />
        </button>

        {/* Header: Balance */}
      <header className="flex flex-col items-center justify-center py-4 mb-4 border-b border-white/10 relative shrink-0">
        <div className="flex items-center justify-center gap-3 mb-2">
          <Box size={32} strokeWidth={1.5} className="text-brand-green drop-shadow-[0_0_20px_rgba(57,255,20,0.6)] md:w-12 md:h-12" />
          <h1 className="text-3xl md:text-5xl font-black tracking-tighter italic leading-none">
            <span className="text-transparent bg-clip-text bg-gradient-to-br from-white to-gray-500 drop-shadow-[0_2px_15px_rgba(255,255,255,0.4)]">TIME</span>
            <span className="text-brand-green drop-shadow-[0_0_25px_rgba(57,255,20,0.8)] ml-1">BOXER</span>
          </h1>
        </div>
        
        <div className="flex flex-col md:flex-row items-center gap-4">
          <div className="flex items-center gap-2">
            {availableMinutes > 0 ? <BatteryFull size={32} className="text-brand-green" /> : <Battery size={32} className="text-gray-600" />}
            <div className={`text-4xl md:text-6xl font-bold font-mono tracking-tighter ${availableMinutes > 0 ? 'text-brand-green drop-shadow-[0_0_15px_rgba(57,255,20,0.4)]' : 'text-gray-500'}`}>
              {availableMinutes}
            </div>
            <span className="text-lg md:text-2xl text-gray-500 mt-2 md:mt-4 font-bold">MIN</span>
          </div>
          
          {/* Data Statistics */}
          <div className="flex flex-col items-center md:items-end md:absolute right-0 top-1/2 md:-translate-y-1/2 text-center md:text-right text-xs md:text-sm text-gray-400 bg-white/5 p-2 md:p-3 rounded-xl border border-white/10 mt-2 md:mt-0">
            <div className="mb-1 uppercase text-[10px] md:text-xs tracking-widest opacity-60">All Time Stats</div>
            <div className="flex md:block gap-4">
              <div>Earned: <span className="text-brand-green font-mono font-bold">{totalEarned}</span>m</div>
              <div>Spent: <span className="text-brand-red font-mono font-bold">{totalSpent}</span>m</div>
            </div>
          </div>
        </div>
      </header>
      {/* Main Zones */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-8 flex-1 md:min-h-0 pb-6 md:pb-0">
        
        {/* EARN ZONE */}
        <section className="bg-bg-panel rounded-3xl p-4 md:p-6 border border-white/5 flex flex-col relative md:h-full">
          <div className="flex items-center justify-between mb-4 md:mb-6 shrink-0">
            <div className="flex items-center gap-3">
              <div className="w-3 h-3 rounded-full bg-brand-green shadow-[0_0_10px_#39FF14]"></div>
              <h2 className="text-xl md:text-2xl font-bold tracking-wide">EARN TIME</h2>
            </div>
            <button onClick={() => handleAddTask('earn')} className="text-brand-green hover:bg-brand-green/20 p-2 rounded-full transition-colors">
              <Plus size={20} className="md:w-6 md:h-6" />
            </button>
          </div>

          <div className="flex flex-col gap-3 md:overflow-y-auto md:pr-2 pb-4 flex-1">
            {(earnTasks || []).map(task => {
              const IconComp = ICON_MAP[task.icon] || ICON_MAP.Star;
              return (
                <div key={task.id} className="relative group flex items-center bg-white/5 hover:bg-white/10 transition-colors rounded-2xl border border-transparent hover:border-brand-green/30">
                  <button 
                    onClick={() => handleTaskClick(task.duration, task.reward)}
                    className="flex-1 flex items-center justify-between p-4 md:p-5 pr-14 md:pr-5"
                  >
                    <div className="flex items-center gap-4">
                      <div className="bg-brand-green/10 p-3 rounded-xl text-brand-green group-hover:scale-110 transition-transform">
                        <IconComp size={24} />
                      </div>
                      <div className="text-left">
                        <div className="font-bold text-lg">{task.title}</div>
                        <div className="text-xs text-brand-green/60 uppercase tracking-widest font-mono">Target: {task.duration}m</div>
                      </div>
                    </div>
                    <div className="text-brand-green font-mono font-bold text-xl drop-shadow-[0_0_5px_rgba(57,255,20,0.3)]">+{task.reward}m</div>
                  </button>
                  
                  {/* Edit/Delete Controls */}
                  <div className="absolute right-2 top-1/2 -translate-y-1/2 flex flex-col md:flex-row gap-2 opacity-100 md:opacity-0 md:group-hover:opacity-100 transition-opacity">
                    <button onClick={() => promptEditTask(task, 'earn')} className="bg-gray-800/80 backdrop-blur-sm text-gray-300 hover:text-white p-2 rounded-full shadow-lg border border-gray-600 hover:border-brand-green">
                      <Pencil size={14} />
                    </button>
                    <button onClick={() => promptDeleteTask(task.id, 'earn')} className="bg-gray-800/80 backdrop-blur-sm text-gray-300 hover:text-red-500 p-2 rounded-full shadow-lg border border-gray-600 hover:border-brand-red">
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </section>

        {/* SPEND ZONE */}
        <section className="bg-bg-panel rounded-3xl p-4 md:p-6 border border-white/5 flex flex-col relative md:h-full">
          
          {/* Spend Cooldown Overlay */}
          {isCoolingDown && (
            <div className="absolute inset-0 z-40 bg-black/80 backdrop-blur-sm rounded-3xl flex flex-col items-center justify-center border border-red-500/30">
              <Lock size={48} className="text-red-500 mb-4 animate-pulse" />
              <div className="text-red-500 font-bold text-xl tracking-widest uppercase">EYE REST COOLDOWN</div>
              <div className="text-red-500 font-mono text-3xl font-bold mt-2">{formatCooldown(cooldownRemaining)}</div>
            </div>
          )}

          <div className="flex flex-col mb-4 md:mb-6 shrink-0">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-3">
                <div className="w-3 h-3 rounded-full bg-brand-red shadow-[0_0_10px_#FF073A]"></div>
                <h2 className="text-xl md:text-2xl font-bold tracking-wide">SPEND TIME</h2>
              </div>
              <button onClick={() => handleAddTask('spend')} className="text-brand-red hover:bg-brand-red/20 p-2 rounded-full transition-colors z-30">
                <Plus size={20} className="md:w-6 md:h-6" />
              </button>
            </div>
            
            {/* Daily Cap & Cooldown Info */}
            <div className="bg-white/5 p-2 md:p-3 rounded-xl border border-white/10 flex flex-col gap-2">
              <div className="flex items-center justify-between group">
                <div className="flex items-center gap-2 text-xs md:text-sm">
                  <span className="text-gray-400">Daily Screen Limit:</span>
                  <span className={`font-mono font-bold ${actualTodaySpent >= dailyCap ? 'text-red-500' : 'text-white'}`}>
                    {actualTodaySpent} / {dailyCap}m
                  </span>
                </div>
                <button onClick={handleEditDailyCap} className="text-gray-500 hover:text-white p-1 rounded transition-colors opacity-100 md:opacity-0 md:group-hover:opacity-100 z-30">
                  <Pencil size={12} className="md:w-[14px] md:h-[14px]" />
                </button>
              </div>
              <div className="flex items-center justify-between group">
                <div className="flex items-center gap-2 text-xs md:text-sm">
                  <span className="text-gray-400">Eye Rest Cooldown:</span>
                  <span className="text-white font-mono font-bold">{cooldownDuration}m</span>
                </div>
                <button onClick={handleEditCooldown} className="text-gray-500 hover:text-white p-1 rounded transition-colors opacity-100 md:opacity-0 md:group-hover:opacity-100 z-30">
                  <Pencil size={12} className="md:w-[14px] md:h-[14px]" />
                </button>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3 md:overflow-y-auto md:pr-2 pb-4 flex-1 content-start">
            {(spendTasks || []).map(task => {
              const IconComp = ICON_MAP[task.icon] || ICON_MAP.Star;
              const hitLimit = actualTodaySpent + task.duration > dailyCap;
              const canAfford = availableMinutes >= task.cost && !hitLimit;
              
              return (
                <div key={task.id} className="relative group">
                  <button 
                    onClick={() => handleSpendClick(task.duration, task.cost)}
                    disabled={isCoolingDown}
                    className={`w-full h-full flex flex-col items-center justify-center gap-3 p-6 rounded-2xl border transition-all ${canAfford ? 'bg-brand-red/10 border-brand-red/30 hover:bg-brand-red/20 text-white cursor-pointer hover:scale-105' : 'bg-white/5 border-transparent text-gray-600 cursor-not-allowed'}`}
                  >
                    <IconComp size={32} className={canAfford ? 'text-brand-red' : ''} />
                    <div className="font-bold text-center">{task.title}</div>
                    <div className="flex flex-col items-center">
                      <div className="font-mono text-sm opacity-80">Cost: -{task.cost}m</div>
                      <div className="text-xs text-gray-500 mt-1">Plays: {task.duration}m</div>
                    </div>
                  </button>

                  {/* Edit/Delete Controls */}
                  <div className="absolute top-2 right-2 flex gap-1 opacity-100 md:opacity-0 md:group-hover:opacity-100 transition-opacity z-30">
                    <button onClick={() => promptEditTask(task, 'spend')} className="bg-gray-800/80 backdrop-blur-sm text-gray-300 hover:text-white p-2 rounded-full shadow-lg border border-gray-600 hover:border-brand-red">
                      <Pencil size={14} />
                    </button>
                    <button onClick={() => promptDeleteTask(task.id, 'spend')} className="bg-gray-800/80 backdrop-blur-sm text-gray-300 hover:text-red-500 p-2 rounded-full shadow-lg border border-gray-600 hover:border-brand-red">
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </section>

      </div>
    </div>
    </>
  );
}

export default App;
