use std::env;
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. 构建gRPC proto文件
    let proto_dir = "src/proto";
    let proto_files = ["analytics.proto"];
    
    let mut config = tonic_build::configure();
    
    // 设置输出目录
    let out_dir = PathBuf::from(env::var("OUT_DIR")?);
    config = config.out_dir(&out_dir);
    
    // 编译proto文件
    let proto_paths: Vec<PathBuf> = proto_files
        .iter()
        .map(|f| PathBuf::from(proto_dir).join(f))
        .filter(|p| p.exists())
        .collect();
    
    if !proto_paths.is_empty() {
        config
            .build_server(true)
            .build_client(true)
            .compile(&proto_paths, &[proto_dir])?;
    }
    
    // 2. 处理Python集成（如果启用）
    #[cfg(feature = "python-bridge")]
    {
        // 配置PyO3
        pyo3_build_config::add_extension_module_link_args();
        
        // 设置Python模块路径
        let python_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR")?)
            .join("python");
        println!("cargo:rustc-env=PYTHON_MODULE_PATH={}", python_dir.display());
        
        // 检查Python环境
        if let Ok(python_path) = env::var("PYTHON_SYS_EXECUTABLE") {
            println!("cargo:rustc-env=PYTHON_EXECUTABLE={}", python_path);
        }
    }
    
    // 3. 环境检测
    if env::var("ANALYTICS_RUST_ONLY").is_ok() {
        println!("cargo:rustc-cfg=feature=\"rust-only\"");
    }
    
    // 4. 重新构建触发条件
    println!("cargo:rerun-if-changed=src/proto/");
    println!("cargo:rerun-if-changed=python/");
    println!("cargo:rerun-if-env-changed=ANALYTICS_RUST_ONLY");
    
    Ok(())
} 