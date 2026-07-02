# -*- coding: utf-8 -*-
from __future__ import annotations

import ctypes
import os
import queue
import subprocess
import sys
import threading
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk


WINDOW_SIZE = "1060x720"


def enable_dpi_awareness() -> None:
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(1)
    except Exception:
        try:
            ctypes.windll.user32.SetProcessDPIAware()
        except Exception:
            pass


def project_root() -> Path:
    base = Path(sys.executable if getattr(sys, "frozen", False) else __file__).resolve().parent
    candidates = [base, base.parent, Path.cwd()]
    for item in candidates:
        if (item / "scripts" / "SnipeIt-OneClick.ps1").exists():
            return item
    return base


ROOT = project_root()
SCRIPT = ROOT / "scripts" / "SnipeIt-OneClick.ps1"
ICON = ROOT / "assets" / "app-icon.ico"


TEXT = {
    "zh": {
        "window_title": "一键 Docker 部署 Snipe-IT",
        "subtitle": "图形化部署、维护和局域网访问工具",
        "project_folder": "项目目录",
        "language": "English",
        "main": "主要操作",
        "network": "网络与上传",
        "maintenance": "维护工具",
        "local": "本地工具",
        "deploy": "一键部署并启动",
        "open": "打开 Snipe-IT 网页",
        "status": "查看运行状态",
        "validate": "环境检查",
        "upload": "修复上传限制 100M",
        "name_required": "启用资产名称必填",
        "access": "访问设置",
        "access_title": "访问设置",
        "port": "访问端口",
        "access_mode": "访问模式",
        "local_mode": "仅本机访问",
        "lan_mode": "局域网访问",
        "apply": "应用",
        "cancel": "取消",
        "invalid_port": "端口必须是 1 到 65535 之间的数字。",
        "lan": "启用局域网访问",
        "diagnose": "局域网访问诊断",
        "update": "更新 Snipe-IT",
        "backup": "备份数据",
        "stop": "停止服务",
        "offline": "生成离线部署包",
        "folder": "打开项目文件夹",
        "address": "打开访问地址文件",
        "backups": "打开备份目录",
        "docker": "打开 Docker Desktop",
        "status_title": "当前状态",
        "ready": "请选择左侧操作。",
        "running": "正在执行：{title}",
        "done": "执行完成。",
        "failed": "执行失败，请查看日志。",
        "log": "执行日志",
        "clear": "清空",
        "tip": "提示：EXE 是图形化入口，实际部署仍由 scripts\\SnipeIt-OneClick.ps1 执行。",
        "busy": "已有任务正在执行，请等待完成。",
        "missing_script": "找不到部署脚本，请把 EXE 放在项目根目录内。",
        "missing_path": "找不到文件或目录：\n{path}",
        "missing_docker": "找不到 Docker Desktop，请先安装或使用一键部署。",
        "access_summary": "端口 {port}，{mode}",
        "completed_line": "[完成] {title}",
        "failed_line": "[失败] {title}，退出码：{code}",
        "exception_line": "[异常] {error}",
    },
    "en": {
        "window_title": "One-click Docker Snipe-IT",
        "subtitle": "GUI deployment, maintenance, and LAN access tool",
        "project_folder": "Project folder",
        "language": "中文",
        "main": "Main",
        "network": "Network and Upload",
        "maintenance": "Maintenance",
        "local": "Local Tools",
        "deploy": "Deploy and Start",
        "open": "Open Snipe-IT",
        "status": "Show Status",
        "validate": "Environment Check",
        "upload": "Fix Upload Limit 100M",
        "name_required": "Require Asset Name",
        "access": "Access Settings",
        "access_title": "Access Settings",
        "port": "Port",
        "access_mode": "Access mode",
        "local_mode": "Local only",
        "lan_mode": "LAN access",
        "apply": "Apply",
        "cancel": "Cancel",
        "invalid_port": "Port must be a number from 1 to 65535.",
        "lan": "Enable LAN Access",
        "diagnose": "LAN Diagnostics",
        "update": "Update Snipe-IT",
        "backup": "Backup Data",
        "stop": "Stop Services",
        "offline": "Prepare Offline Package",
        "folder": "Open Project Folder",
        "address": "Open Access Address",
        "backups": "Open Backup Folder",
        "docker": "Open Docker Desktop",
        "status_title": "Status",
        "ready": "Choose an action on the left.",
        "running": "Running: {title}",
        "done": "Done.",
        "failed": "Failed. Check the log.",
        "log": "Execution Log",
        "clear": "Clear",
        "tip": "Note: the EXE is a GUI launcher. The actual deployment runs scripts\\SnipeIt-OneClick.ps1.",
        "busy": "A task is already running. Please wait.",
        "missing_script": "Deployment script not found. Put the EXE in the project root.",
        "missing_path": "File or folder not found:\n{path}",
        "missing_docker": "Docker Desktop was not found. Install it first or run deployment.",
        "access_summary": "Port {port}, {mode}",
        "completed_line": "[Done] {title}",
        "failed_line": "[Failed] {title}, exit code: {code}",
        "exception_line": "[Exception] {error}",
    },
}


SECTIONS = [
    (
        "main",
        [
            ("deploy", "ps", "BootstrapDeploy", True),
            ("open", "ps", "Open", False),
            ("status", "ps", "Status", False),
            ("validate", "ps", "Validate", False),
        ],
    ),
    (
        "network",
        [
            ("access", "settings", "ConfigureAccess", False),
            ("upload", "ps", "SetUploadLimit", False),
            ("name_required", "ps", "ApplyAssetNameRequiredPatch", False),
            ("lan", "ps", "ConfigureLan", False),
            ("diagnose", "ps", "Diagnose", False),
        ],
    ),
    (
        "maintenance",
        [
            ("update", "ps", "Update", False),
            ("backup", "ps", "Backup", False),
            ("stop", "ps", "Stop", False),
            ("offline", "ps", "PrepareOffline", False),
        ],
    ),
    (
        "local",
        [
            ("folder", "local", "folder", False),
            ("address", "local", "address", False),
            ("backups", "local", "backups", False),
            ("docker", "local", "docker", False),
        ],
    ),
]


class Launcher(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.lang = "zh"
        self.scale = self._detect_scale()
        self.running = False
        self.log_queue: queue.Queue[tuple[str, str | None]] = queue.Queue()
        self.action_buttons: list[tuple[ttk.Button, str, str]] = []
        self.text_widgets: list[tuple[ttk.Label, str]] = []

        self.title(self._t("window_title"))
        self.geometry(WINDOW_SIZE)
        self.minsize(self._s(860), self._s(560))
        self.configure(bg="#f3f6fb")

        if ICON.exists():
            try:
                self.iconbitmap(str(ICON))
            except Exception:
                pass

        self._setup_styles()
        self._build_ui()
        self._refresh_language()
        self.after(120, self._drain_log_queue)

    def _detect_scale(self) -> float:
        width = max(self.winfo_screenwidth(), 1)
        height = max(self.winfo_screenheight(), 1)
        return max(0.9, min(1.25, min(width / 1440, height / 900)))

    def _s(self, value: int) -> int:
        return int(round(value * self.scale))

    def _t(self, key: str) -> str:
        return TEXT[self.lang][key]

    def _setup_styles(self) -> None:
        self.style = ttk.Style(self)
        self.style.theme_use("clam")

        base_font = ("Microsoft YaHei UI", self._s(10))
        small_font = ("Microsoft YaHei UI", self._s(9))
        title_font = ("Microsoft YaHei UI", self._s(18), "bold")
        section_font = ("Microsoft YaHei UI", self._s(10), "bold")

        self.style.configure("Root.TFrame", background="#f3f6fb")
        self.style.configure("Header.TFrame", background="#ffffff")
        self.style.configure("Sidebar.TFrame", background="#ffffff")
        self.style.configure("Card.TFrame", background="#ffffff")
        self.style.configure("Title.TLabel", background="#ffffff", foreground="#111827", font=title_font)
        self.style.configure("Subtitle.TLabel", background="#ffffff", foreground="#64748b", font=small_font)
        self.style.configure("Section.TLabel", background="#ffffff", foreground="#334155", font=section_font)
        self.style.configure("Body.TLabel", background="#ffffff", foreground="#1f2937", font=base_font)
        self.style.configure("Muted.TLabel", background="#ffffff", foreground="#64748b", font=small_font)
        self.style.configure("RootMuted.TLabel", background="#f3f6fb", foreground="#64748b", font=small_font)
        self.style.configure("Primary.TButton", font=section_font, padding=(self._s(14), self._s(10)), background="#2563eb", foreground="#ffffff")
        self.style.configure("Tool.TButton", font=base_font, padding=(self._s(12), self._s(9)), background="#eef2f7", foreground="#111827")
        self.style.configure("Ghost.TButton", font=base_font, padding=(self._s(10), self._s(7)), background="#ffffff", foreground="#111827")
        self.style.map("Primary.TButton", background=[("active", "#1d4ed8"), ("disabled", "#93c5fd")])
        self.style.map("Tool.TButton", background=[("active", "#dbe4ef"), ("disabled", "#f1f5f9")])
        self.style.map("Ghost.TButton", background=[("active", "#f1f5f9")])

    def _build_ui(self) -> None:
        self.columnconfigure(0, weight=1)
        self.rowconfigure(1, weight=1)

        header = ttk.Frame(self, style="Header.TFrame", padding=(self._s(22), self._s(16)))
        header.grid(row=0, column=0, sticky="ew")
        header.columnconfigure(0, weight=1)

        title_area = ttk.Frame(header, style="Header.TFrame")
        title_area.grid(row=0, column=0, sticky="ew")
        title_area.columnconfigure(0, weight=1)

        self.title_label = self._label(title_area, "window_title", "Title.TLabel")
        self.title_label.grid(row=0, column=0, sticky="w")

        self.lang_button = ttk.Button(title_area, style="Ghost.TButton", command=self._toggle_language)
        self.lang_button.grid(row=0, column=1, sticky="e")

        self.subtitle_label = self._label(header, "subtitle", "Subtitle.TLabel")
        self.subtitle_label.grid(row=1, column=0, sticky="w", pady=(self._s(4), 0))

        self.path_var = tk.StringVar()
        self.path_label = ttk.Label(header, textvariable=self.path_var, style="Subtitle.TLabel")
        self.path_label.grid(row=2, column=0, sticky="ew", pady=(self._s(3), 0))
        header.bind("<Configure>", self._wrap_header_text)

        body = ttk.Frame(self, style="Root.TFrame", padding=self._s(16))
        body.grid(row=1, column=0, sticky="nsew")
        body.columnconfigure(1, weight=1)
        body.rowconfigure(0, weight=1)

        sidebar_outer = ttk.Frame(body, style="Sidebar.TFrame", width=self._s(290))
        sidebar_outer.grid(row=0, column=0, sticky="nsw")
        sidebar_outer.grid_propagate(False)
        sidebar_outer.rowconfigure(0, weight=1)
        sidebar_outer.columnconfigure(0, weight=1)

        self.side_canvas = tk.Canvas(sidebar_outer, bg="#ffffff", highlightthickness=0, bd=0)
        self.side_canvas.grid(row=0, column=0, sticky="nsew")
        side_scroll = ttk.Scrollbar(sidebar_outer, orient="vertical", command=self.side_canvas.yview)
        side_scroll.grid(row=0, column=1, sticky="ns")
        self.side_canvas.configure(yscrollcommand=side_scroll.set)

        self.side_content = ttk.Frame(self.side_canvas, style="Sidebar.TFrame", padding=(self._s(16), self._s(14)))
        self.side_window = self.side_canvas.create_window((0, 0), window=self.side_content, anchor="nw")
        self.side_content.bind("<Configure>", self._update_side_scroll)
        self.side_canvas.bind("<Configure>", self._fit_side_width)
        self.side_canvas.bind("<Enter>", lambda _event: self.side_canvas.bind_all("<MouseWheel>", self._on_side_mousewheel))
        self.side_canvas.bind("<Leave>", lambda _event: self.side_canvas.unbind_all("<MouseWheel>"))

        main = ttk.Frame(body, style="Root.TFrame")
        main.grid(row=0, column=1, sticky="nsew", padx=(self._s(16), 0))
        main.columnconfigure(0, weight=1)
        main.rowconfigure(1, weight=1)

        self._build_sidebar()
        self._build_main(main)

    def _build_sidebar(self) -> None:
        for section_key, items in SECTIONS:
            label = self._label(self.side_content, section_key, "Section.TLabel")
            label.pack(anchor="w", pady=(self._s(12), self._s(8)))

            for label_key, kind, command, primary in items:
                style = "Primary.TButton" if primary else "Tool.TButton"
                button = ttk.Button(
                    self.side_content,
                    style=style,
                    command=lambda k=label_key, t=kind, c=command: self._dispatch_action(k, t, c),
                )
                button.pack(fill="x", pady=self._s(3))
                self.action_buttons.append((button, label_key, kind))

    def _build_main(self, parent: ttk.Frame) -> None:
        status_card = ttk.Frame(parent, style="Card.TFrame", padding=self._s(18))
        status_card.grid(row=0, column=0, sticky="ew")
        status_card.columnconfigure(0, weight=1)

        self._label(status_card, "status_title", "Body.TLabel").grid(row=0, column=0, sticky="w")
        self.status_var = tk.StringVar(value=self._t("ready"))
        ttk.Label(status_card, textvariable=self.status_var, style="Muted.TLabel").grid(row=1, column=0, sticky="ew", pady=(self._s(8), 0))

        self.progress = ttk.Progressbar(status_card, mode="indeterminate")
        self.progress.grid(row=2, column=0, sticky="ew", pady=(self._s(14), 0))

        log_card = ttk.Frame(parent, style="Card.TFrame", padding=self._s(12))
        log_card.grid(row=1, column=0, sticky="nsew", pady=(self._s(14), 0))
        log_card.columnconfigure(0, weight=1)
        log_card.rowconfigure(1, weight=1)

        log_header = ttk.Frame(log_card, style="Card.TFrame")
        log_header.grid(row=0, column=0, sticky="ew")
        log_header.columnconfigure(0, weight=1)
        self._label(log_header, "log", "Body.TLabel").grid(row=0, column=0, sticky="w")
        self.clear_button = ttk.Button(log_header, style="Ghost.TButton", command=self._clear_log)
        self.clear_button.grid(row=0, column=1, sticky="e")

        log_frame = ttk.Frame(log_card, style="Card.TFrame")
        log_frame.grid(row=1, column=0, sticky="nsew", pady=(self._s(10), 0))
        log_frame.columnconfigure(0, weight=1)
        log_frame.rowconfigure(0, weight=1)

        self.log = tk.Text(
            log_frame,
            wrap="word",
            bg="#0f172a",
            fg="#dbeafe",
            insertbackground="#ffffff",
            relief="flat",
            padx=self._s(12),
            pady=self._s(10),
            font=("Consolas", self._s(10)),
        )
        self.log.grid(row=0, column=0, sticky="nsew")

        scroll = ttk.Scrollbar(log_frame, orient="vertical", command=self.log.yview)
        scroll.grid(row=0, column=1, sticky="ns")
        self.log.configure(yscrollcommand=scroll.set)

        self.tip_label = self._label(parent, "tip", "RootMuted.TLabel")
        self.tip_label.grid(row=2, column=0, sticky="ew", pady=(self._s(10), 0))

        if not SCRIPT.exists():
            self._append_log(f"[ERROR] {SCRIPT}\n")
            self.status_var.set(self._t("missing_script"))

    def _label(self, parent: ttk.Frame, key: str, style: str) -> ttk.Label:
        label = ttk.Label(parent, text=self._t(key), style=style)
        self.text_widgets.append((label, key))
        return label

    def _wrap_header_text(self, event: tk.Event) -> None:
        wrap = max(self._s(420), event.width - self._s(60))
        self.path_label.configure(wraplength=wrap)
        self.subtitle_label.configure(wraplength=wrap)

    def _update_side_scroll(self, _event: tk.Event) -> None:
        self.side_canvas.configure(scrollregion=self.side_canvas.bbox("all"))

    def _fit_side_width(self, event: tk.Event) -> None:
        self.side_canvas.itemconfigure(self.side_window, width=event.width)

    def _on_side_mousewheel(self, event: tk.Event) -> None:
        self.side_canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")

    def _toggle_language(self) -> None:
        self.lang = "en" if self.lang == "zh" else "zh"
        self._refresh_language()

    def _refresh_language(self) -> None:
        self.title(self._t("window_title"))
        self.lang_button.configure(text=self._t("language"))
        self.clear_button.configure(text=self._t("clear"))
        self.path_var.set(f"{self._t('project_folder')}：{ROOT}")
        for label, key in self.text_widgets:
            label.configure(text=self._t(key))
        for button, key, _kind in self.action_buttons:
            button.configure(text=self._t(key))
        if not self.running:
            self.status_var.set(self._t("ready") if SCRIPT.exists() else self._t("missing_script"))

    def _dispatch_action(self, label_key: str, kind: str, command: str) -> None:
        if kind == "ps":
            self._run_ps_action(command, self._t(label_key))
        elif kind == "settings":
            self._show_access_settings()
        else:
            self._run_local_action(command)

    def _run_ps_action(self, action: str, title: str, extra_args: list[str] | None = None) -> None:
        if self.running:
            messagebox.showinfo(self._t("window_title"), self._t("busy"))
            return

        if not SCRIPT.exists():
            messagebox.showerror(self._t("window_title"), self._t("missing_script"))
            return

        self.running = True
        self._set_ps_buttons_state("disabled")
        self.progress.start(12)
        self.status_var.set(self._t("running").format(title=title))
        self._append_log(f"\n========== {title} ==========\n")

        thread = threading.Thread(target=self._worker, args=(action, title, self.lang, extra_args or []), daemon=True)
        thread.start()

    def _worker(self, action: str, title: str, lang: str, extra_args: list[str]) -> None:
        command = [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(SCRIPT),
            "-Action",
            action,
        ] + extra_args

        try:
            process = subprocess.Popen(
                command,
                cwd=str(ROOT),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                env=os.environ.copy(),
            )

            assert process.stdout is not None
            for line in process.stdout:
                self.log_queue.put(("log", line))

            code = process.wait()
            if code == 0:
                self.log_queue.put(("log", "\n" + TEXT[lang]["completed_line"].format(title=title) + "\n"))
                self.log_queue.put(("ok", None))
            else:
                self.log_queue.put(("log", "\n" + TEXT[lang]["failed_line"].format(title=title, code=code) + "\n"))
                self.log_queue.put(("fail", None))
        except Exception as exc:
            self.log_queue.put(("log", "\n" + TEXT[lang]["exception_line"].format(error=exc) + "\n"))
            self.log_queue.put(("fail", None))

    def _drain_log_queue(self) -> None:
        try:
            while True:
                kind, text = self.log_queue.get_nowait()
                if kind == "ok":
                    self._finish_task(self._t("done"))
                elif kind == "fail":
                    self._finish_task(self._t("failed"))
                elif text is not None:
                    self._append_log(text)
        except queue.Empty:
            pass
        self.after(120, self._drain_log_queue)

    def _finish_task(self, message: str) -> None:
        self.running = False
        self.progress.stop()
        self.status_var.set(message)
        self._set_ps_buttons_state("normal")

    def _run_local_action(self, action: str) -> None:
        if action == "folder":
            self._open_path(ROOT)
        elif action == "address":
            self._open_path(ROOT / "局域网访问地址.txt")
        elif action == "backups":
            self._open_path(ROOT / "backups")
        elif action == "docker":
            self._open_docker_desktop()

    def _show_access_settings(self) -> None:
        if self.running:
            messagebox.showinfo(self._t("window_title"), self._t("busy"))
            return

        settings = self._read_access_settings()
        dialog = tk.Toplevel(self)
        dialog.title(self._t("access_title"))
        dialog.configure(bg="#ffffff")
        dialog.resizable(False, False)
        dialog.transient(self)
        dialog.grab_set()

        frame = ttk.Frame(dialog, style="Card.TFrame", padding=self._s(18))
        frame.grid(row=0, column=0, sticky="nsew")
        frame.columnconfigure(1, weight=1)

        ttk.Label(frame, text=self._t("port"), style="Body.TLabel").grid(row=0, column=0, sticky="w", padx=(0, self._s(12)), pady=self._s(8))
        port_var = tk.StringVar(value=str(settings["port"]))
        port_entry = ttk.Entry(frame, textvariable=port_var, width=18)
        port_entry.grid(row=0, column=1, sticky="ew", pady=self._s(8))

        ttk.Label(frame, text=self._t("access_mode"), style="Body.TLabel").grid(row=1, column=0, sticky="w", padx=(0, self._s(12)), pady=self._s(8))
        mode_var = tk.StringVar(value=settings["mode"])
        mode_box = ttk.Frame(frame, style="Card.TFrame")
        mode_box.grid(row=1, column=1, sticky="w", pady=self._s(8))
        ttk.Radiobutton(mode_box, text=self._t("lan_mode"), variable=mode_var, value="Lan").pack(anchor="w")
        ttk.Radiobutton(mode_box, text=self._t("local_mode"), variable=mode_var, value="Local").pack(anchor="w", pady=(self._s(4), 0))

        button_box = ttk.Frame(frame, style="Card.TFrame")
        button_box.grid(row=2, column=0, columnspan=2, sticky="e", pady=(self._s(14), 0))

        def apply_settings() -> None:
            raw_port = port_var.get().strip()
            if not raw_port.isdigit() or not 1 <= int(raw_port) <= 65535:
                messagebox.showwarning(self._t("window_title"), self._t("invalid_port"), parent=dialog)
                return

            mode = mode_var.get()
            mode_text = self._t("lan_mode") if mode == "Lan" else self._t("local_mode")
            dialog.destroy()
            title = self._t("access_summary").format(port=raw_port, mode=mode_text)
            self._run_ps_action(
                "ConfigureAccess",
                title,
                ["-Port", raw_port, "-AccessMode", mode],
            )

        ttk.Button(button_box, text=self._t("cancel"), style="Ghost.TButton", command=dialog.destroy).pack(side="right", padx=(self._s(8), 0))
        ttk.Button(button_box, text=self._t("apply"), style="Primary.TButton", command=apply_settings).pack(side="right")

        port_entry.focus_set()
        dialog.update_idletasks()
        x = self.winfo_rootx() + (self.winfo_width() - dialog.winfo_width()) // 2
        y = self.winfo_rooty() + (self.winfo_height() - dialog.winfo_height()) // 2
        dialog.geometry(f"+{max(x, 0)}+{max(y, 0)}")

    def _read_access_settings(self) -> dict[str, str | int]:
        port = 8088
        bind_ip = "0.0.0.0"
        env_path = ROOT / ".env"
        if env_path.exists():
            try:
                for line in env_path.read_text(encoding="utf-8", errors="ignore").splitlines():
                    if "=" not in line or line.strip().startswith("#"):
                        continue
                    key, value = line.split("=", 1)
                    if key == "APP_PORT" and value.strip().isdigit():
                        port = int(value.strip())
                    elif key == "APP_BIND_IP":
                        bind_ip = value.strip()
            except Exception:
                pass
        return {"port": port, "mode": "Local" if bind_ip == "127.0.0.1" else "Lan"}

    def _open_path(self, path: Path) -> None:
        if not path.exists():
            messagebox.showwarning(self._t("window_title"), self._t("missing_path").format(path=path))
            return
        try:
            os.startfile(path)  # type: ignore[attr-defined]
        except Exception as exc:
            messagebox.showerror(self._t("window_title"), str(exc))

    def _open_docker_desktop(self) -> None:
        candidates = [
            Path(os.environ.get("ProgramFiles", "")) / "Docker" / "Docker" / "Docker Desktop.exe",
            Path(os.environ.get("ProgramFiles(x86)", "")) / "Docker" / "Docker" / "Docker Desktop.exe",
            Path(os.environ.get("LocalAppData", "")) / "Docker" / "Docker Desktop.exe",
        ]
        for item in candidates:
            if item.exists():
                self._open_path(item)
                return
        messagebox.showwarning(self._t("window_title"), self._t("missing_docker"))

    def _append_log(self, text: str) -> None:
        self.log.insert("end", text)
        self.log.see("end")

    def _clear_log(self) -> None:
        self.log.delete("1.0", "end")

    def _set_ps_buttons_state(self, state: str) -> None:
        for button, _key, kind in self.action_buttons:
            if kind in ("ps", "settings"):
                button.configure(state=state)


if __name__ == "__main__":
    enable_dpi_awareness()
    app = Launcher()
    app.mainloop()
