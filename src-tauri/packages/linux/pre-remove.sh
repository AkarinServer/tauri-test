#!/bin/bash
# 修复脚本格式问题（如果脚本内容是错误的格式）
SERVICE_SCRIPT="/usr/bin/clash-verge-service-uninstall"

if [ -f "${SERVICE_SCRIPT}" ]; then
    # 检查脚本内容是否正确（错误格式的文件只有一行，包含字面量 \n）
    line_count=$(wc -l < "${SERVICE_SCRIPT}" 2>/dev/null || echo "0")
    if [ "$line_count" -lt 2 ] || grep -q "\\\\nexit" "${SERVICE_SCRIPT}" 2>/dev/null; then
        # 修复脚本格式：创建正确的脚本内容（包含换行符）
        printf '#!/bin/bash\nexit 0\n' > "${SERVICE_SCRIPT}"
        chmod +x "${SERVICE_SCRIPT}"
    fi

    # 即使服务卸载脚本返回非零，也不要阻塞 dpkg
    "${SERVICE_SCRIPT}" || echo "[rv-verge] clash-verge-service-uninstall exited with $?, continuing"
else
    echo "[rv-verge] skip clash-verge-service-uninstall: not installed"
fi

exit 0
