import { ShieldAlert, Lock, PlayCircle, PlusCircle } from 'lucide-react';

export default function Onboarding({ onComplete }) {
  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md z-[100] flex items-center justify-center p-4">
      <div className="bg-[#111] border border-white/10 rounded-3xl p-8 max-w-2xl w-full text-left shadow-2xl relative overflow-hidden">
        {/* Decorative background glow */}
        <div className="absolute top-0 right-0 w-64 h-64 bg-brand-green/10 blur-[100px] rounded-full pointer-events-none"></div>
        <div className="absolute bottom-0 left-0 w-64 h-64 bg-brand-red/10 blur-[100px] rounded-full pointer-events-none"></div>

        <div className="relative z-10">
          <h2 className="text-3xl sm:text-4xl font-black italic tracking-tighter mb-2 text-transparent bg-clip-text bg-gradient-to-r from-white to-gray-500">
            WELCOME TO <span className="text-brand-green drop-shadow-[0_0_10px_rgba(57,255,20,0.5)]">TIMEBOXER</span>
          </h2>
          <p className="text-gray-400 mb-8 font-mono text-sm border-b border-white/10 pb-4">硬核防沉迷 · 儿童时间管理系统</p>
          
          <div className="space-y-6">
            <div className="flex gap-4 items-start">
              <div className="bg-brand-green/10 p-3 rounded-xl text-brand-green shrink-0">
                <PlayCircle size={24} />
              </div>
              <div>
                <h3 className="font-bold text-lg text-white mb-1">赚取时间 (Earn Time)</h3>
                <p className="text-gray-400 text-sm leading-relaxed">必须完成设定的基础时间，否则收益为 0！完成目标后将无缝开启<strong className="text-[#FFD700]">“超额秒表”</strong>，多坚持一分钟就多赚一分钟。</p>
              </div>
            </div>
            
            <div className="flex gap-4 items-start">
              <div className="bg-brand-red/10 p-3 rounded-xl text-brand-red shrink-0">
                <ShieldAlert size={24} />
              </div>
              <div>
                <h3 className="font-bold text-lg text-white mb-1">强管控消费 (Spend Time)</h3>
                <p className="text-gray-400 text-sm leading-relaxed">家长可随时修改<strong className="text-white">“每日最大屏幕限额”</strong>。每次结束娱乐后，系统将强制进入不可逆的<strong className="text-red-500">“护眼冷却期”</strong>，杜绝连续沉迷。</p>
              </div>
            </div>

            <div className="flex gap-4 items-start">
              <div className="bg-blue-500/10 p-3 rounded-xl text-blue-500 shrink-0">
                <Lock size={24} />
              </div>
              <div>
                <h3 className="font-bold text-lg text-white mb-1">家长锁 (默认密码: <span className="bg-blue-500/20 px-2 py-0.5 rounded font-mono">1234</span>)</h3>
                <p className="text-gray-400 text-sm leading-relaxed">增删任务、修改限额、提前强退计时，均需要密码！进入应用后请点击右上角 <strong className="text-white">⚙️ 图标</strong> 立即修改您的专属密码。</p>
              </div>
            </div>

            <div className="flex gap-4 items-start">
              <div className="bg-purple-500/10 p-3 rounded-xl text-purple-500 shrink-0">
                <PlusCircle size={24} />
              </div>
              <div>
                <h3 className="font-bold text-lg text-white mb-1">完全自定义 (Customization)</h3>
                <p className="text-gray-400 text-sm leading-relaxed">点击区域标题旁的 <strong>+</strong> 号自由创建任务，或点击卡片上的 <strong>✏️ 小铅笔</strong> 随时修改任务参数。您可以巧妙设置（如：玩15分钟扣除30个币）来实现“防沉迷汇率”。</p>
              </div>
            </div>
          </div>

          <button 
            onClick={onComplete}
            className="mt-10 w-full py-4 rounded-xl bg-brand-green text-black font-bold text-lg tracking-widest hover:bg-white transition-all shadow-[0_0_20px_rgba(57,255,20,0.3)] hover:shadow-[0_0_30px_rgba(255,255,255,0.6)] transform hover:-translate-y-1"
          >
            我已了解，立即开始体验
          </button>
        </div>
      </div>
    </div>
  );
}
