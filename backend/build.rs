fn main() {
    println!("cargo:rerun-if-changed=src/slices");

    // 构建脚本暂时为空，未来可以添加其他构建时任务
    println!("🚀 构建完成");
}
