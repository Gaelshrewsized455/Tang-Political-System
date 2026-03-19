"""
文件锁工具 — 防止多进程并发读写 JSON 文件导致数据丢失。
Windows 版本使用 msvcrt 和文件锁机制。

用法:
    from file_lock import atomic_json_update, atomic_json_read

    # 原子读取
    data = atomic_json_read(path, default=[])

    # 原子更新（读 → 修改 → 写回，全程持锁）
    def modifier(tasks):
        tasks.append(new_task)
        return tasks 
    atomic_json_update(path, modifier, default=[])
"""
import json
import os
import pathlib
import tempfile
from typing import Any, Callable

# Windows 特定的导入
try:
    import msvcrt
    import portalocker
    HAS_PORTALOCKER = True
except ImportError:
    HAS_PORTALOCKER = False
    import threading
    # 备用：使用线程锁（单进程内有效）
    _file_locks = {}
    _file_locks_lock = threading.Lock()


def _get_lock_file(path: pathlib.Path) -> pathlib.Path:
    return path.parent / (path.name + '.lock')


def _acquire_lock(lock_file: pathlib.Path, exclusive: bool = False) -> Any:
    """获取文件锁，返回锁句柄"""
    lock_file.parent.mkdir(parents=True, exist_ok=True)
    
    if HAS_PORTALOCKER:
        # 使用 portalocker 实现跨进程锁
        import portalocker
        mode = 'r+' if exclusive else 'r'
        try:
            fd = open(str(lock_file), mode)
        except FileNotFoundError:
            fd = open(str(lock_file), 'w+')
        
        lock_flags = portalocker.LOCK_EX if exclusive else portalocker.LOCK_SH
        portalocker.lock(fd, lock_flags)
        return fd
    else:
        # 备用：使用线程锁（仅单进程内有效）
        lock_path = str(lock_file)
        with _file_locks_lock:
            if lock_path not in _file_locks:
                _file_locks[lock_path] = threading.Lock()
            lock = _file_locks[lock_path]
        lock.acquire()
        return lock


def _release_lock(handle: Any) -> None:
    """释放文件锁"""
    if HAS_PORTALOCKER:
        import portalocker
        try:
            portalocker.unlock(handle)
            handle.close()
        except:
            pass
    else:
        handle.release()


def atomic_json_read(path: pathlib.Path, default: Any = None) -> Any:
    """持锁读取 JSON 文件。"""
    lock_file = _get_lock_file(path)
    handle = _acquire_lock(lock_file, exclusive=False)
    try:
        if path.exists():
            try:
                return json.loads(path.read_text(encoding='utf-8'))
            except Exception:
                return default
        return default
    finally:
        _release_lock(handle)


def atomic_json_update(
    path: pathlib.Path,
    modifier: Callable[[Any], Any],
    default: Any = None,
) -> Any:
    """
    原子地读取 → 修改 → 写回 JSON 文件。
    modifier(data) 应返回修改后的数据。
    使用临时文件 + rename 保证写入原子性。
    """
    lock_file = _get_lock_file(path)
    handle = _acquire_lock(lock_file, exclusive=True)
    try:
        # Read
        try:
            data = json.loads(path.read_text(encoding='utf-8')) if path.exists() else default
        except Exception:
            data = default
        # Modify
        result = modifier(data)
        # Atomic write via temp file + rename
        tmp_fd, tmp_path = tempfile.mkstemp(
            dir=str(path.parent), suffix='.tmp', prefix=path.stem + '_'
        )
        try:
            with os.fdopen(tmp_fd, 'w', encoding='utf-8') as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
            os.replace(tmp_path, str(path))
        except Exception:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
            raise
        return result
    finally:
        _release_lock(handle)


def atomic_json_write(path: pathlib.Path, data: Any) -> None:
    """原子写入 JSON 文件（持排他锁 + tmpfile rename）。
    直接写入，不读取现有内容（避免 atomic_json_update 的多余读开销）。
    """
    lock_file = _get_lock_file(path)
    handle = _acquire_lock(lock_file, exclusive=True)
    try:
        tmp_fd, tmp_path = tempfile.mkstemp(
            dir=str(path.parent), suffix='.tmp', prefix=path.stem + '_'
        )
        try:
            with os.fdopen(tmp_fd, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            os.replace(tmp_path, str(path))
        except Exception:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
            raise
    finally:
        _release_lock(handle)
