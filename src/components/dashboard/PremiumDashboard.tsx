import React, { useState, useEffect } from 'react';
import { 
  Monitor, Shield, Terminal, Activity, Settings, Wifi, Cpu, HardDrive, 
  Network, Play, Square, Clipboard, Volume2, FileText, Printer, MessageSquare,
  Power, Eye, Lock, Globe, Zap, BarChart3, Users, FolderSync, Radio,
  RefreshCw, CheckCircle, XCircle, AlertCircle, Download, Upload, 
  Maximize2, Minimize2, Camera, Mic, MicOff, PhoneCall
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

interface ServiceStatus {
  name: string;
  port: number;
  protocol: 'tcp' | 'udp' | 'both';
  status: 'active' | 'inactive' | 'warning';
  latency?: number;
}

interface ConnectionStats {
  latency: number;
  bandwidth: string;
  fps: number;
  quality: 'excellent' | 'good' | 'fair' | 'poor';
}

const PremiumDashboard = () => {
  const [services, setServices] = useState<ServiceStatus[]>([
    { name: 'RDP', port: 3389, protocol: 'tcp', status: 'active', latency: 12 },
    { name: 'VNC', port: 5900, protocol: 'tcp', status: 'active', latency: 15 },
    { name: 'SSH', port: 2277, protocol: 'tcp', status: 'active', latency: 8 },
    { name: 'RustDesk', port: 21116, protocol: 'udp', status: 'active', latency: 5 },
    { name: 'Audio', port: 4713, protocol: 'tcp', status: 'active' },
    { name: 'Guacamole', port: 8080, protocol: 'tcp', status: 'inactive' },
  ]);

  const [stats, setStats] = useState<ConnectionStats>({
    latency: 12,
    bandwidth: '45.2 Mbps',
    fps: 60,
    quality: 'excellent'
  });

  const [isRecording, setIsRecording] = useState(false);
  const [audioEnabled, setAudioEnabled] = useState(true);
  const [clipboardSync, setClipboardSync] = useState(true);
  const [activeMonitor, setActiveMonitor] = useState(1);
  const [monitors] = useState([1, 2, 3]);

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'active': return <CheckCircle className="w-4 h-4 text-green-500" />;
      case 'inactive': return <XCircle className="w-4 h-4 text-red-500" />;
      case 'warning': return <AlertCircle className="w-4 h-4 text-yellow-500" />;
      default: return null;
    }
  };

  const getQualityColor = (quality: string) => {
    switch (quality) {
      case 'excellent': return 'text-green-500';
      case 'good': return 'text-blue-500';
      case 'fair': return 'text-yellow-500';
      case 'poor': return 'text-red-500';
      default: return 'text-gray-500';
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 text-white p-6">
      <header className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-bold tracking-tight bg-gradient-to-r from-cyan-400 to-blue-500 bg-clip-text text-transparent">
            SkyView Premium
          </h1>
          <p className="text-slate-400">Enterprise Remote Access Dashboard</p>
        </div>
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2 px-4 py-2 rounded-full bg-green-500/20 border border-green-500/30">
            <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
            <span className="text-green-400 text-sm font-medium">System Online</span>
          </div>
          <Button variant="outline" size="icon" className="border-slate-600 hover:bg-slate-700">
            <Settings className="w-5 h-5" />
          </Button>
        </div>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <Card className="bg-slate-800/50 border-slate-700">
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-slate-400 text-xs uppercase tracking-wide">Latency</p>
                <p className="text-2xl font-bold text-cyan-400">{stats.latency}ms</p>
              </div>
              <Zap className="w-8 h-8 text-cyan-500/50" />
            </div>
          </CardContent>
        </Card>
        
        <Card className="bg-slate-800/50 border-slate-700">
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-slate-400 text-xs uppercase tracking-wide">Bandwidth</p>
                <p className="text-2xl font-bold text-green-400">{stats.bandwidth}</p>
              </div>
              <BarChart3 className="w-8 h-8 text-green-500/50" />
            </div>
          </CardContent>
        </Card>
        
        <Card className="bg-slate-800/50 border-slate-700">
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-slate-400 text-xs uppercase tracking-wide">FPS</p>
                <p className="text-2xl font-bold text-purple-400">{stats.fps}</p>
              </div>
              <Activity className="w-8 h-8 text-purple-500/50" />
            </div>
          </CardContent>
        </Card>
        
        <Card className="bg-slate-800/50 border-slate-700">
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-slate-400 text-xs uppercase tracking-wide">Quality</p>
                <p className={`text-2xl font-bold capitalize ${getQualityColor(stats.quality)}`}>
                  {stats.quality}
                </p>
              </div>
              <Radio className={`w-8 h-8 ${getQualityColor(stats.quality)} opacity-50`} />
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
        <Card className="lg:col-span-2 bg-slate-800/50 border-slate-700">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-lg">
              <Shield className="w-5 h-5 text-cyan-400" />
              Remote Access Services
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
              {services.map((service) => (
                <div 
                  key={service.name}
                  className={`p-4 rounded-lg border transition-all cursor-pointer hover:scale-[1.02] ${
                    service.status === 'active' 
                      ? 'bg-slate-700/50 border-green-500/30 hover:border-green-500/50' 
                      : 'bg-slate-800/50 border-slate-600 hover:border-slate-500'
                  }`}
                >
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-semibold">{service.name}</span>
                    {getStatusIcon(service.status)}
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-slate-400">
                      :{service.port} ({service.protocol.toUpperCase()})
                    </span>
                    {service.latency && (
                      <span className="text-green-400">{service.latency}ms</span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card className="bg-slate-800/50 border-slate-700">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-lg">
              <Monitor className="w-5 h-5 text-cyan-400" />
              Quick Controls
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <Button 
              variant={isRecording ? "destructive" : "outline"} 
              className="w-full justify-start gap-2"
              onClick={() => setIsRecording(!isRecording)}
            >
              {isRecording ? <Square className="w-4 h-4" /> : <Camera className="w-4 h-4" />}
              {isRecording ? 'Stop Recording' : 'Record Session'}
            </Button>
            
            <Button 
              variant="outline" 
              className={`w-full justify-start gap-2 ${audioEnabled ? 'border-green-500/50 text-green-400' : ''}`}
              onClick={() => setAudioEnabled(!audioEnabled)}
            >
              {audioEnabled ? <Volume2 className="w-4 h-4" /> : <MicOff className="w-4 h-4" />}
              Audio {audioEnabled ? 'On' : 'Off'}
            </Button>
            
            <Button 
              variant="outline" 
              className={`w-full justify-start gap-2 ${clipboardSync ? 'border-blue-500/50 text-blue-400' : ''}`}
              onClick={() => setClipboardSync(!clipboardSync)}
            >
              <Clipboard className="w-4 h-4" />
              Clipboard {clipboardSync ? 'Synced' : 'Disabled'}
            </Button>
            
            <Button variant="outline" className="w-full justify-start gap-2">
              <FileText className="w-4 h-4" />
              File Transfer
            </Button>
            
            <Button variant="outline" className="w-full justify-start gap-2">
              <MessageSquare className="w-4 h-4" />
              Chat
            </Button>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <Card className="bg-slate-800/50 border-slate-700">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-lg">
              <Maximize2 className="w-5 h-5 text-cyan-400" />
              Multi-Monitor
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex gap-2 mb-4">
              {monitors.map((mon) => (
                <button
                  key={mon}
                  onClick={() => setActiveMonitor(mon)}
                  className={`flex-1 p-4 rounded-lg border-2 transition-all ${
                    activeMonitor === mon
                      ? 'border-cyan-500 bg-cyan-500/10'
                      : 'border-slate-600 bg-slate-700/30 hover:border-slate-500'
                  }`}
                >
                  <Monitor className={`w-8 h-8 mx-auto mb-2 ${activeMonitor === mon ? 'text-cyan-400' : 'text-slate-400'}`} />
                  <p className="text-center text-sm">Display {mon}</p>
                </button>
              ))}
            </div>
            <div className="flex gap-2">
              <Button variant="outline" size="sm" className="flex-1">
                <Maximize2 className="w-4 h-4 mr-2" />
                Fullscreen
              </Button>
              <Button variant="outline" size="sm" className="flex-1">
                All Monitors
              </Button>
            </div>
          </CardContent>
        </Card>

        <Card className="bg-slate-800/50 border-slate-700">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-lg">
              <Power className="w-5 h-5 text-cyan-400" />
              Power Management
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-3">
              <Button variant="outline" className="h-auto py-4 flex-col gap-2">
                <Power className="w-6 h-6" />
                <span>Wake-on-LAN</span>
              </Button>
              <Button variant="outline" className="h-auto py-4 flex-col gap-2">
                <RefreshCw className="w-6 h-6" />
                <span>Reboot</span>
              </Button>
              <Button variant="outline" className="h-auto py-4 flex-col gap-2">
                <Lock className="w-6 h-6" />
                <span>Lock Screen</span>
              </Button>
              <Button variant="outline" className="h-auto py-4 flex-col gap-2 text-red-400 hover:text-red-300">
                <Power className="w-6 h-6" />
                <span>Shutdown</span>
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card className="bg-slate-800/50 border-slate-700">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-lg">
              <Lock className="w-5 h-5 text-cyan-400" />
              Security
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex items-center justify-between p-3 rounded-lg bg-slate-700/30">
              <div className="flex items-center gap-2">
                <Shield className="w-4 h-4 text-green-400" />
                <span>TLS 1.3 Encryption</span>
              </div>
              <CheckCircle className="w-4 h-4 text-green-400" />
            </div>
            <div className="flex items-center justify-between p-3 rounded-lg bg-slate-700/30">
              <div className="flex items-center gap-2">
                <Lock className="w-4 h-4 text-green-400" />
                <span>2FA Enabled</span>
              </div>
              <CheckCircle className="w-4 h-4 text-green-400" />
            </div>
            <div className="flex items-center justify-between p-3 rounded-lg bg-slate-700/30">
              <div className="flex items-center gap-2">
                <Eye className="w-4 h-4 text-yellow-400" />
                <span>Session Recording</span>
              </div>
              {isRecording ? (
                <div className="flex items-center gap-1">
                  <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
                  <span className="text-red-400 text-sm">REC</span>
                </div>
              ) : (
                <span className="text-slate-400 text-sm">Off</span>
              )}
            </div>
          </CardContent>
        </Card>

        <Card className="bg-slate-800/50 border-slate-700">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-lg">
              <Globe className="w-5 h-5 text-cyan-400" />
              Network
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="p-3 rounded-lg bg-slate-700/30">
              <p className="text-slate-400 text-xs mb-1">Local IP</p>
              <p className="font-mono">192.168.0.140</p>
            </div>
            <div className="p-3 rounded-lg bg-slate-700/30">
              <p className="text-slate-400 text-xs mb-1">Tailscale IP</p>
              <p className="font-mono text-purple-400">100.x.x.x</p>
            </div>
            <div className="p-3 rounded-lg bg-slate-700/30">
              <p className="text-slate-400 text-xs mb-1">Public Hostname</p>
              <p className="font-mono text-cyan-400">cgs1.tplinkdns.com</p>
            </div>
          </CardContent>
        </Card>

        <Card className="bg-slate-800/50 border-slate-700">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-lg">
              <Terminal className="w-5 h-5 text-cyan-400" />
              Quick Connect
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 font-mono text-sm">
            <div className="p-2 rounded bg-black/50 border border-slate-700">
              <span className="text-slate-400">RDP:</span> 192.168.0.140:3389
            </div>
            <div className="p-2 rounded bg-black/50 border border-slate-700">
              <span className="text-slate-400">VNC:</span> 192.168.0.140:5900
            </div>
            <div className="p-2 rounded bg-black/50 border border-slate-700">
              <span className="text-slate-400">SSH:</span> ssh -p 2277 user@192.168.0.140
            </div>
            <div className="p-2 rounded bg-black/50 border border-slate-700">
              <span className="text-slate-400">Web:</span> http://192.168.0.140:8080
            </div>
          </CardContent>
        </Card>
      </div>

      <footer className="mt-8 text-center text-slate-500 text-sm">
        <p>SkyView Premium v7.0 - Enterprise Remote Access</p>
        <p className="text-xs mt-1">UDP P2P • TLS 1.3 • 2FA • Session Recording • File Transfer</p>
      </footer>
    </div>
  );
};

export default PremiumDashboard;
