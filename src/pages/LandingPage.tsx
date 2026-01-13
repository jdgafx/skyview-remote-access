import React from 'react';
import { Monitor, Shield, Zap, Terminal, Github, ArrowRight, Laptop, Lock, Globe } from 'lucide-react';

const LandingPage = () => {
  return (
    <div className="min-h-screen bg-slate-950 text-slate-50 font-sans selection:bg-indigo-500/30">
      {/* Navigation */}
      <nav className="border-b border-slate-800/50 bg-slate-950/50 backdrop-blur-xl sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="bg-indigo-600 p-1.5 rounded-lg">
              <Monitor className="w-5 h-5 text-white" />
            </div>
            <span className="font-bold text-xl tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white to-slate-400">
              SkyView Remote
            </span>
          </div>
          <div className="hidden md:flex items-center gap-8 text-sm font-medium text-slate-400">
            <a href="#features" className="hover:text-white transition-colors">Features</a>
            <a href="#setup" className="hover:text-white transition-colors">Setup</a>
            <a href="https://github.com/jdgafx/skyview-remote-access" className="flex items-center gap-2 bg-slate-800 hover:bg-slate-700 text-white px-4 py-2 rounded-full transition-all">
              <Github className="w-4 h-4" />
              GitHub
            </a>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="relative pt-20 pb-32 overflow-hidden">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-full bg-[radial-gradient(circle_at_50%_0%,rgba(79,70,229,0.15),transparent_50%)]" />
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative">
          <div className="text-center max-w-3xl mx-auto">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 text-xs font-semibold mb-8">
              <Zap className="w-3 h-3 text-indigo-400 fill-indigo-400" />
              <span>SkyView Premium v7.1 is live</span>
            </div>
            <h1 className="text-5xl md:text-7xl font-extrabold tracking-tight mb-6 bg-clip-text text-transparent bg-gradient-to-b from-white to-slate-500 leading-tight">
              Enterprise Remote Access, Simplified.
            </h1>
            <p className="text-lg text-slate-400 mb-10 leading-relaxed">
              Automatic orchestration of VNC, RDP, and SSH tunnels. High-performance desktop streaming for developers, with one-line deployment.
            </p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <button className="w-full sm:w-auto px-8 py-4 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-xl transition-all flex items-center justify-center gap-2 group">
                Get Started
                <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
              </button>
              <div className="flex items-center gap-2 text-slate-400 text-sm font-medium px-4 py-4">
                <Shield className="w-4 h-4 text-indigo-500" />
                End-to-End Encryption
              </div>
            </div>
          </div>

          {/* Terminal Mockup */}
          <div className="mt-20 max-w-4xl mx-auto">
            <div className="bg-slate-900 rounded-2xl border border-slate-800 shadow-2xl overflow-hidden">
              <div className="flex items-center gap-2 px-4 py-3 bg-slate-800/50 border-b border-slate-800">
                <div className="flex gap-1.5">
                  <div className="w-3 h-3 rounded-full bg-red-500/50" />
                  <div className="w-3 h-3 rounded-full bg-yellow-500/50" />
                  <div className="w-3 h-3 rounded-full bg-green-500/50" />
                </div>
                <div className="flex-1 text-center text-xs text-slate-500 font-mono uppercase tracking-widest">Setup Dashboard</div>
              </div>
              <div className="p-6 font-mono text-sm sm:text-base">
                <div className="flex gap-3 mb-2">
                  <span className="text-indigo-500">$</span>
                  <span className="text-slate-200">curl -sSL skyview.sh | bash</span>
                </div>
                <div className="text-slate-400 mb-4 animate-pulse">Initializing SkyView Engine...</div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="p-3 rounded-lg bg-indigo-500/5 border border-indigo-500/10">
                    <div className="text-xs text-indigo-400 mb-1 font-bold uppercase tracking-wider">VNC STATUS</div>
                    <div className="text-slate-200">ACTIVE: Display :4 (24-bit)</div>
                  </div>
                  <div className="p-3 rounded-lg bg-emerald-500/5 border border-emerald-500/10">
                    <div className="text-xs text-emerald-400 mb-1 font-bold uppercase tracking-wider">RDP STATUS</div>
                    <div className="text-slate-200">ACTIVE: 192.168.1.100:3389</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Grid */}
      <section id="features" className="py-24 bg-slate-900/50 border-y border-slate-800/50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-3xl font-bold mb-4">Powerful Core Features</h2>
            <p className="text-slate-400">Everything you need for seamless remote desktop access.</p>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <FeatureCard 
              icon={<Laptop className="w-6 h-6 text-indigo-500" />}
              title="KDE Plasma Integration"
              description="Full KDE session support with high-quality color rendering and window management."
            />
            <FeatureCard 
              icon={<Shield className="w-6 h-6 text-emerald-500" />}
              title="Secured Protocols"
              description="TLS 1.3 encryption for RDP and SSH tunneling for all legacy VNC connections."
            />
            <FeatureCard 
              icon={<Globe className="w-6 h-6 text-orange-500" />}
              title="Web-Based Portal"
              description="Access your desktop from any browser via our built-in Guacamole-based gateway."
            />
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 border-t border-slate-800/50 text-center">
        <p className="text-slate-500 text-sm">
          &copy; 2026 SkyView Remote Access. Built for the open-source community.
        </p>
      </footer>
    </div>
  );
};

const FeatureCard = ({ icon, title, description }: { icon: React.ReactNode, title: string, description: string }) => (
  <div className="p-8 rounded-2xl bg-slate-950 border border-slate-800 hover:border-indigo-500/50 transition-all hover:-translate-y-1">
    <div className="mb-4">{icon}</div>
    <h3 className="text-xl font-bold mb-2">{title}</h3>
    <p className="text-slate-400 text-sm leading-relaxed">{description}</p>
  </div>
);

export default LandingPage;
