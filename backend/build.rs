fn main() {
    println!("cargo:rerun-if-changed=src/slices");
    println!("cargo:rerun-if-changed=proto/backend.proto");
    println!("cargo:rerun-if-changed=proto/analytics.proto");

    // 构建Backend gRPC proto文件
    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .out_dir("src/")
        .compile_protos(&["proto/backend.proto"], &["proto/"])
        .unwrap_or_else(|e| panic!("Failed to compile backend proto files: {}", e));

    // 构建Analytics Engine客户端proto文件
    tonic_build::configure()
        .build_server(false)
        .build_client(true)
        .out_dir("src/")
        .compile_protos(&["proto/analytics.proto"], &["proto/"])
        .unwrap_or_else(|e| panic!("Failed to compile analytics proto files: {}", e));

    println!("🚀 构建完成");
}
