/**
 * SkyView API Server - Express backend for shell script bridge
 * Handles execution of shell commands and returns JSON responses
 */

import { spawn } from 'child_process';
import path from 'path';

const LIB_DIR = path.join(process.cwd(), 'lib');

type CommandResult = {
  success: boolean;
  stdout: string;
  stderr: string;
  exitCode: number | null;
  error?: string;
  [key: string]: unknown;
};

function executeScript(scriptName: string, args: string[] = []): Promise<CommandResult> {
  return new Promise((resolve) => {
    const scriptPath = path.join(LIB_DIR, scriptName);

    const proc = spawn('bash', [scriptPath, ...args], {
      env: { ...process.env, LIB_DIR },
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    proc.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    proc.on('close', (code) => {
      resolve({
        success: code === 0,
        stdout,
        stderr,
        exitCode: code,
      });
    });

    proc.on('error', (error) => {
      resolve({
        success: false,
        stdout: '',
        stderr: error.message,
        exitCode: null,
      });
    });
  });
}

function sourceAndExecute(commands: string[]): Promise<CommandResult> {
  return new Promise((resolve) => {
    const libDir = LIB_DIR;

    const fullScript = `
      source "${libDir}/utils.sh" 2>/dev/null || true
      source "${libDir}/detect_os.sh" 2>/dev/null || true
      source "${libDir}/detect_de.sh" 2>/dev/null || true

      ${commands.join('\n')}
    `;

    const proc = spawn('bash', ['-c', fullScript], {
      env: { ...process.env, LIB_DIR },
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    proc.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    proc.on('close', (code) => {
      resolve({
        success: code === 0,
        stdout,
        stderr,
        exitCode: code,
      });
    });

    proc.on('error', (error) => {
      resolve({
        success: false,
        stdout: '',
        stderr: error.message,
        exitCode: null,
      });
    });
  });
}

export const apiRoutes: Record<string, (body?: Record<string, unknown>) => Promise<Record<string, unknown>>> = {
  '/api/detect-system': async () => {
    const result = await sourceAndExecute([
      'detect_os',
      'detect_de',
      'detect_session_type',
      'echo "OS:$SKYVIEW_OS_NAME DE:$SKYVIEW_DE SESSION:$SKYVIEW_SESSION_TYPE"',
    ]);

    const match = result.stdout.match(/OS:(\S+) DE:(\S+) SESSION:(\S+)/);
    return {
      os: match?.[1] || 'unknown',
      version: process.env.SKYVIEW_OS_VERSION || '',
      de: match?.[2] || 'unknown',
      sessionType: match?.[3] || 'unknown',
    };
  },

  '/api/rdp/status': async () => {
    return executeScript('config_rdp.sh', ['--status']);
  },

  '/api/rdp/configure': async (body) => {
    const method = (body?.method as string) || 'auto';
    return executeScript('config_rdp.sh', ['--configure', '--method', method]);
  },

  '/api/ssh/status': async () => {
    return executeScript('config_ssh.sh', ['--status']);
  },

  '/api/ssh/configure': async (body) => {
    const args = ['--configure'];
    if (body?.port) args.push('--port', String(body.port));
    if (body?.passwordAuth !== undefined) args.push('--password-auth', String(body.passwordAuth));
    return executeScript('config_ssh.sh', args);
  },

  '/api/native-rdp/status': async () => {
    return executeScript('config_native.sh', ['--status']);
  },

  '/api/native-rdp/configure': async () => {
    return executeScript('config_native.sh', ['--configure']);
  },

  '/api/vnc/status': async () => {
    return executeScript('config_vnc.sh', ['--status']);
  },

  '/api/vnc/configure': async (body) => {
    const args = ['--configure'];
    if (body?.port) args.push('--port', String(body.port));
    return executeScript('config_vnc.sh', args);
  },

  '/api/services/all': async () => {
    const [rdp, ssh, vnc, native] = await Promise.all([
      executeScript('config_rdp.sh', ['--status']),
      executeScript('config_ssh.sh', ['--status']),
      executeScript('config_vnc.sh', ['--status']),
      executeScript('config_native.sh', ['--status']),
    ]);

    return { rdp, ssh, vnc, nativeRdp: native };
  },

  '/api/start': async (body) => {
    const service = body?.service as string;
    const scripts: Record<string, string> = {
      rdp: 'config_rdp.sh',
      ssh: 'config_ssh.sh',
      vnc: 'config_vnc.sh',
      'native-rdp': 'config_native.sh',
    };

    const script = scripts[service];
    if (!script) {
      return { success: false, error: 'Unknown service' };
    }

    return executeScript(script, ['--start']);
  },

  '/api/stop': async (body) => {
    const service = body?.service as string;
    const scripts: Record<string, string> = {
      rdp: 'config_rdp.sh',
      ssh: 'config_ssh.sh',
      vnc: 'config_vnc.sh',
      'native-rdp': 'config_native.sh',
    };

    const script = scripts[service];
    if (!script) {
      return { success: false, error: 'Unknown service' };
    }

    return executeScript(script, ['--stop']);
  },

  '/api/restart': async (body) => {
    const service = body?.service as string;
    const scripts: Record<string, string> = {
      rdp: 'config_rdp.sh',
      ssh: 'config_ssh.sh',
      vnc: 'config_vnc.sh',
      'native-rdp': 'config_native.sh',
    };

    const script = scripts[service];
    if (!script) {
      return { success: false, error: 'Unknown service' };
    }

    return executeScript(script, ['--restart']);
  },
};

export default apiRoutes;
