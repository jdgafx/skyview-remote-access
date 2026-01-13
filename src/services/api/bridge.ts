/**
 * SkyView Remote Access - Shell Script Bridge
 * Provides type-safe interface to shell script modules
 */

export interface SystemInfo {
  os: string;
  version: string;
  de: string;
  sessionType: 'wayland' | 'x11' | 'headless';
  packageManager: string;
  arch: string;
}

export interface ServiceStatus {
  service: string;
  status: 'active' | 'inactive' | 'unknown';
  port: number | undefined;
  running: boolean;
  enabled: boolean;
}

export interface RDPConfig {
  method: 'xrdp' | 'vnc' | 'native' | 'ssh';
  port: number;
  tlsEnabled: boolean;
  maxBpp: number;
}

export interface SSHConfig {
  port: number;
  passwordAuth: boolean;
  rootLogin: boolean;
  keyPath: string;
  keyExists: boolean;
  x11Forwarding: boolean;
}

export interface NativeRDPConfig {
  port: number;
  desktopEnvironment: string;
  sessionType: string;
  deSupported: boolean;
}

export type DetectionResult = {
  os: string;
  de: string;
  session: string;
  displayServer: string;
  availableMethods: string[];
  recommendedMethod: string;
};

class SkyViewBridge {
  private baseUrl = '/api';

  private async exec(command: string): Promise<Record<string, unknown>> {
    try {
      const response = await fetch(`${this.baseUrl}/exec`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ command }),
      });

      if (!response.ok) {
        throw new Error(`Command failed: ${response.statusText}`);
      }

      return response.json();
    } catch (error) {
      console.error('Bridge exec error:', error);
      throw error;
    }
  }

  async detectSystem(): Promise<SystemInfo> {
    const result = await this.exec('detect_system');
    return result as unknown as SystemInfo;
  }

  async getRDPStatus(): Promise<ServiceStatus> {
    const result = await this.exec('get_rdp_status');
    return result as unknown as ServiceStatus;
  }

  async configureRDP(method: string): Promise<{ success: boolean; message: string }> {
    const result = await this.exec(`configure_rdp --method ${method}`);
    return result as { success: boolean; message: string };
  }

  async getSSHStatus(): Promise<ServiceStatus> {
    const result = await this.exec('get_ssh_status');
    return result as unknown as ServiceStatus;
  }

  async configureSSH(config: Partial<SSHConfig>): Promise<{ success: boolean; message: string }> {
    const args = Object.entries(config)
      .map(([k, v]) => `--${k} ${v}`)
      .join(' ');
    const result = await this.exec(`configure_ssh ${args}`);
    return result as { success: boolean; message: string };
  }

  async getNativeRDPStatus(): Promise<ServiceStatus> {
    const result = await this.exec('get_native_rdp_status');
    return result as unknown as ServiceStatus;
  }

  async configureNativeRDP(): Promise<{ success: boolean; message: string }> {
    const result = await this.exec('configure_native_rdp');
    return result as { success: boolean; message: string };
  }

  async getVNCStatus(): Promise<ServiceStatus> {
    const result = await this.exec('get_vnc_status');
    return result as unknown as ServiceStatus;
  }

  async configureVNC(config: Record<string, unknown>): Promise<{ success: boolean; message: string }> {
    const args = Object.entries(config)
      .map(([k, v]) => `--${k} ${v}`)
      .join(' ');
    const result = await this.exec(`configure_vnc ${args}`);
    return result as { success: boolean; message: string };
  }

  async getAllServicesStatus(): Promise<{
    rdp: ServiceStatus;
    ssh: ServiceStatus;
    vnc: ServiceStatus;
    nativeRdp: ServiceStatus;
  }> {
    const [rdp, ssh, vnc, nativeRdp] = await Promise.all([
      this.getRDPStatus(),
      this.getSSHStatus(),
      this.getVNCStatus(),
      this.getNativeRDPStatus(),
    ]);

    return { rdp, ssh, vnc, nativeRdp };
  }

  async getDetectionResult(): Promise<DetectionResult> {
    const result = await this.exec('detect_all');
    return result as unknown as DetectionResult;
  }

  async startService(service: 'rdp' | 'ssh' | 'vnc' | 'native-rdp'): Promise<{ success: boolean }> {
    const result = await this.exec(`start_${service}`);
    return result as { success: boolean };
  }

  async stopService(service: 'rdp' | 'ssh' | 'vnc' | 'native-rdp'): Promise<{ success: boolean }> {
    const result = await this.exec(`stop_${service}`);
    return result as { success: boolean };
  }

  async restartService(service: 'rdp' | 'ssh' | 'vnc' | 'native-rdp'): Promise<{ success: boolean }> {
    const result = await this.exec(`restart_${service}`);
    return result as { success: boolean };
  }
}

export const skyviewBridge = new SkyViewBridge();
export default skyviewBridge;
