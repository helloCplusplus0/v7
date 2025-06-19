use criterion::{black_box, criterion_group, criterion_main, Criterion};
use fmod_slice::core::performance_analysis::*;

fn benchmark_static_dispatch(c: &mut Criterion) {
    c.bench_function("static_dispatch_login", |b| {
        b.iter(|| {
            let auth_service = static_dispatch::JwtAuthService;
            static_dispatch::login(
                black_box(auth_service),
                black_box("admin"),
                black_box("password")
            )
        })
    });
}

fn benchmark_const_generic(c: &mut Criterion) {
    c.bench_function("const_generic_login", |b| {
        b.iter(|| {
            const_generic::login::<{const_generic::JWT_AUTH}>(
                black_box("admin"),
                black_box("password")
            )
        })
    });
}

fn benchmark_hybrid_approach(c: &mut Criterion) {
    c.bench_function("hybrid_approach_login", |b| {
        b.iter(|| {
            hybrid_approach::login::<hybrid_approach::JwtAuthService>(
                black_box("admin"),
                black_box("password")
            )
        })
    });
}

fn benchmark_function_table(c: &mut Criterion) {
    function_table::init_jwt_functions();
    
    c.bench_function("function_table_login", |b| {
        b.iter(|| {
            function_table::login(
                black_box("admin"),
                black_box("password")
            )
        })
    });
}

fn benchmark_trait_object(c: &mut Criterion) {
    trait_object_optimized::init_auth_service();
    
    c.bench_function("trait_object_login", |b| {
        b.iter(|| {
            trait_object_optimized::login(
                black_box("admin"),
                black_box("password")
            )
        })
    });
}

criterion_group!(
    benches,
    benchmark_static_dispatch,
    benchmark_const_generic,
    benchmark_hybrid_approach,
    benchmark_function_table,
    benchmark_trait_object
);
criterion_main!(benches); 