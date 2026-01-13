import React from 'react';
import { Monitor, Shield, Terminal, Activity, Settings, Wifi, Cpu, HardDrive, Network } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

const Dashboard = () => {
  return (
    <div className="min-h-screen bg-background text-foreground p-6">
      <header className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-primary">SkyView Remote</h1>
          <p className="text-muted-foreground">Universal Remote Access Dashboard</p>
        </div>
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-secondary text-sm font-medium">
            <Wifi className="w-4 h-4 text-green-500" />
            <span>System Online</span>
          </div>
          <Button variant="outline" size="icon">
            <Settings className="w-5 h-5" />
          </Button>
        </div>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">CPU Usage</CardTitle>
            <Cpu className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">12.4%</div>
            <p className="text-xs text-muted-foreground">+2.1% from last hour</p>
            <div className="mt-4 h-2 w-full bg-secondary rounded-full overflow-hidden">
              <div className="h-full bg-primary w-[12.4%]" />
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Memory</CardTitle>
            <HardDrive className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">2.4 GB / 8 GB</div>
            <p className="text-xs text-muted-foreground">30% utilized</p>
            <div className="mt-4 h-2 w-full bg-secondary rounded-full overflow-hidden">
              <div className="h-full bg-primary w-[30%]" />
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Network</CardTitle>
            <Network className="w-4 h-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">1.2 MB/s</div>
            <p className="text-xs text-muted-foreground">Stable connection</p>
            <div className="mt-4 h-2 w-full bg-secondary rounded-full overflow-hidden">
              <div className="h-full bg-primary w-[45%]" />
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card className="col-span-1">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Shield className="w-5 h-5 text-primary" />
              Remote Access Methods
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between p-4 rounded-lg border bg-card hover:bg-accent/50 transition-colors cursor-pointer">
              <div className="flex items-center gap-4">
                <div className="p-2 rounded-md bg-primary/10">
                  <Monitor className="w-6 h-6 text-primary" />
                </div>
                <div>
                  <div className="font-semibold">RDP (Remote Desktop)</div>
                  <div className="text-sm text-muted-foreground">Best for Windows clients</div>
                </div>
              </div>
              <div className="text-xs font-medium px-2 py-1 rounded bg-green-500/10 text-green-500">Active</div>
            </div>
            <div className="flex items-center justify-between p-4 rounded-lg border bg-card hover:bg-accent/50 transition-colors cursor-pointer">
              <div className="flex items-center gap-4">
                <div className="p-2 rounded-md bg-primary/10">
                  <Activity className="w-6 h-6 text-primary" />
                </div>
                <div>
                  <div className="font-semibold">VNC (Universal)</div>
                  <div className="text-sm text-muted-foreground">Works on any platform</div>
                </div>
              </div>
              <div className="text-xs font-medium px-2 py-1 rounded bg-green-500/10 text-green-500">Active</div>
            </div>
            <div className="flex items-center justify-between p-4 rounded-lg border bg-card hover:bg-accent/50 transition-colors cursor-pointer">
              <div className="flex items-center gap-4">
                <div className="p-2 rounded-md bg-primary/10">
                  <Terminal className="w-6 h-6 text-primary" />
                </div>
                <div>
                  <div className="font-semibold">SSH (Secure Shell)</div>
                  <div className="text-sm text-muted-foreground">Command line access</div>
                </div>
              </div>
              <div className="text-xs font-medium px-2 py-1 rounded bg-green-500/10 text-green-500">Active</div>
            </div>
          </CardContent>
        </Card>

        <Card className="col-span-1">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Terminal className="w-5 h-5 text-primary" />
              Quick Terminal
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="bg-black rounded-md p-4 font-mono text-sm text-green-400 min-h-[300px]">
              <div className="mb-2">skyview@remote:~$ ./skyview-remote-access.sh --status</div>
              <div className="text-white">
                [10:42:15] [INFO] System: KDE:wayland<br />
                [10:42:16] [✔] RDP listening on port 3389<br />
                [10:42:16] [✔] VNC listening on port 5900<br />
                [10:42:17] [✔] SSH listening on port 2277<br />
                [10:42:17] [INFO] Firewall: UFW (active)<br />
              </div>
              <div className="mt-2 flex items-center gap-2">
                <span>skyview@remote:~$</span>
                <span className="w-2 h-4 bg-green-400 animate-pulse" />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default Dashboard;
