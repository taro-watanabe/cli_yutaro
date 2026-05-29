interface V86Static {
  new (options: V86Options): V86Emulator;
}

interface V86Emulator {
  add_listener(event: V86Event, listener: (...args: never[]) => void): void;
}

interface V86Options {
  wasm_path: string;
  memory_size: number;
  vga_memory_size: number;
  bios: { url: string };
  vga_bios: { url: string };
  bzimage: { url: string };
  initrd: { url: string };
  hda: { url: string; async?: boolean };
  cmdline: string;
  serial_console: {
    type: "xtermjs";
    container: HTMLElement;
  };
  autostart: boolean;
}

type V86Event = "serial0-output-byte" | "emulator-stopped" | "download-progress";

interface BootConfig {
  readonly wasmPath: string;
  readonly biosUrl: string;
  readonly vgabiosUrl: string;
  readonly bzimageUrl: string;
  readonly initrdUrl: string;
  readonly hdaUrl: string;
  readonly cmdline: string;
  readonly memorySize: number;
  readonly vgaMemorySize: number;
  readonly redirectUrl: string;
  readonly promptPattern: string;
  readonly bootTimeoutMs: number;
  readonly asciiArtPath: string;
}

const BOOT_CONFIG: BootConfig = {
  wasmPath: "v86.wasm",
  biosUrl: "seabios.bin",
  vgabiosUrl: "vgabios.bin",
  bzimageUrl: "vmlinuz",
  initrdUrl: "initrd.img",
  hdaUrl: "disk.img",
  cmdline: "console=ttyS0 tsc=reliable",
  memorySize: 128 * 1024 * 1024,
  vgaMemorySize: 2 * 1024 * 1024,
  redirectUrl: "https://yutarowatanabe.com",
  promptPattern: "guest@cli.yutarowatanabe.com",
  bootTimeoutMs: 30_000,
  asciiArtPath: "ascii-loading.txt",
};

function queryElement(id: string): HTMLElement {
  const el = document.getElementById(id);
  if (!el) {
    throw new Error(`Element #${id} not found`);
  }
  return el;
}

class SerialWatcher {
  private readonly buffer: string[] = [];
  private readonly maxBufferLength = 512;
  private booted = false;
  private halted = false;

  get hasBooted(): boolean {
    return this.booted;
  }

  get hasHalted(): boolean {
    return this.halted;
  }

  feed(byte: number): { booted: boolean; halted: boolean } {
    this.buffer.push(String.fromCharCode(byte));
    if (this.buffer.length > this.maxBufferLength) {
      this.buffer.shift();
    }

    const text = this.buffer.join("");

    if (!this.booted && text.includes(BOOT_CONFIG.promptPattern)) {
      this.booted = true;
    }

    if (!this.halted && (text.includes("System halted") || text.includes("Power down"))) {
      this.halted = true;
    }

    return { booted: this.booted, halted: this.halted };
  }
}

class BootLog {
  private readonly el: HTMLElement;
  private lastAppend = 0;
  private pending = "";

  constructor(el: HTMLElement) {
    this.el = el;
  }

  write(char: string): void {
    this.pending += char;
    const now = performance.now();
    if (now - this.lastAppend > 16) {
      this.flush();
    }
  }

  flush(): void {
    if (this.pending.length === 0) return;
    this.el.textContent += this.pending;
    this.pending = "";
    this.lastAppend = performance.now();
    this.el.scrollTop = this.el.scrollHeight;
  }

  clear(): void {
    this.el.textContent = "";
  }
}

function createEmulator(container: HTMLElement): V86Emulator {
  const V86Ctor = (window as unknown as Record<string, V86Static>)["V86"];
  if (!V86Ctor) {
    throw new Error("v86 library not loaded");
  }

  return new V86Ctor({
    wasm_path: BOOT_CONFIG.wasmPath,
    memory_size: BOOT_CONFIG.memorySize,
    vga_memory_size: BOOT_CONFIG.vgaMemorySize,
    bios: { url: BOOT_CONFIG.biosUrl },
    vga_bios: { url: BOOT_CONFIG.vgabiosUrl },
    bzimage: { url: BOOT_CONFIG.bzimageUrl },
    initrd: { url: BOOT_CONFIG.initrdUrl },
    hda: { url: BOOT_CONFIG.hdaUrl },
    cmdline: BOOT_CONFIG.cmdline,
    serial_console: { type: "xtermjs", container },
    autostart: true,
  });
}

function hideLoadingScreen(loadingScreen: HTMLElement): void {
  loadingScreen.classList.add("hidden");
}

function redirectToSite(): void {
  window.location.href = BOOT_CONFIG.redirectUrl;
}

async function loadAsciiArt(el: HTMLElement): Promise<void> {
  try {
    const resp = await fetch(BOOT_CONFIG.asciiArtPath);
    if (resp.ok) {
      el.textContent = await resp.text();
    }
  } catch {
    // Art is optional, skip silently
  }
}

window.onload = () => {
  const terminal = queryElement("terminal");
  const loadingScreen = queryElement("loading-screen");
  const loadingArt = queryElement("loading-art");
  const loadingText = queryElement("loading-text");
  const progressBar = queryElement("progress-bar") as HTMLDivElement;
  const bootLogEl = queryElement("boot-log");
  const watcher = new SerialWatcher();
  const bootLog = new BootLog(bootLogEl);

  loadAsciiArt(loadingArt);
  const emulator = createEmulator(terminal);

  emulator.add_listener("download-progress", (data: { file_index: number; file_count: number; file_name: string; loaded: number; total: number }) => {
    if (data.total > 0) {
      const pct = Math.round((data.loaded / data.total) * 100);
      const name = data.file_name.split("/").pop() ?? data.file_name;
      loadingText.textContent = `Loading ${name}... ${pct}%`;
      progressBar.style.width = `${pct}%`;
    }
  });

  emulator.add_listener("serial0-output-byte", (byte: number) => {
    const char = String.fromCharCode(byte);
    bootLog.write(char);
    const state = watcher.feed(byte);

    if (state.booted) {
      bootLog.flush();
      setTimeout(() => hideLoadingScreen(loadingScreen), 500);
    }

    if (state.halted) {
      bootLog.flush();
      redirectToSite();
    }
  });

  emulator.add_listener("emulator-stopped", () => {
    redirectToSite();
  });

  setTimeout(() => {
    if (!watcher.hasBooted) {
      bootLog.flush();
      hideLoadingScreen(loadingScreen);
    }
  }, BOOT_CONFIG.bootTimeoutMs);
};
