// 延迟加载 Tauri API，减少初始加载时间
let invokeFunction = null;

// 懒加载 Tauri API
async function loadTauriAPI() {
  if (!invokeFunction) {
    const { invoke } = await import('@tauri-apps/api/core');
    invokeFunction = invoke;
  }
  return invokeFunction;
}

// 优化后的 greet 函数
async function greet() {
  const input = document.getElementById('greet-input');
  const msg = document.getElementById('greet-msg');
  
  if (input.value.trim() === '') {
    alert('请输入您的名字');
    return;
  }
  
  try {
    // 延迟加载 API
    const invoke = await loadTauriAPI();
    const message = await invoke('greet', { name: input.value });
    msg.textContent = message;
    msg.style.display = 'block';
  } catch (error) {
    console.error('Error:', error);
    alert('调用失败: ' + error);
  }
}

// DOM 加载完成后初始化事件监听
document.addEventListener('DOMContentLoaded', () => {
  const input = document.getElementById('greet-input');
  if (input) {
    // 允许 Enter 键触发
    input.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') {
        greet();
      }
    });
  }
});

