// RUN: hcl-opt -opt %s | FileCheck %s

module {
    func @add_buffer_at_axis_0(%A: memref<1024x1024xf32>, %B: memref<1024x1024xf32>, %C: memref<1024x1024xf32>)
    {
        %l1 = hcl.create_loop_handle "i" : !hcl.LoopHandle
        %l2 = hcl.create_loop_handle "j" : !hcl.LoopHandle
        %s = hcl.create_stage_handle "s" : !hcl.StageHandle
        affine.for %i = 0 to 1024 {
            // CHECK: %3 = memref.alloc() : memref<1024xf32>
            // CHECK: %cst = constant 0.000000e+00 : f32
            // CHECK: affine.for %arg4 = 0 to 1024 {
            // CHECK:     affine.store %cst, %3[%arg4] : memref<1024xf32>
            // CHECK: } {loop_name = "j_init", pipeline_ii = 1 : i32}
            affine.for %j = 0 to 1024 {
                // B[i, j] = A[i, j] + 1
                // CHECK: %4 = affine.load %arg0[%arg3, %arg4] : memref<1024x1024xf32>
                %a = affine.load %A[%i, %j] : memref<1024x1024xf32>
                %cst = constant 1.0 : f32
                %sum = addf %a, %cst: f32 //register
                // CHECK: affine.store %5, %3[%arg4] : memref<1024xf32>
                affine.store %sum, %B[%i, %j] : memref<1024x1024xf32>
            } { loop_name = "j" }
            // CHECK: affine.for %arg4 = 0 to 1024 {
            // CHECK:     %4 = affine.load %3[%arg4] : memref<1024xf32>
            // CHECK:     affine.store %4, %arg1[%arg3, %arg4] : memref<1024x1024xf32>
            // CHECK: } {loop_name = "j_back", pipeline_ii = 1 : i32}
        } { loop_name = "i", stage_name = "s" }
        %buf = hcl.buffer_at(%s, %B: memref<1024x1024xf32>, %l1) -> memref<1024xf32>
        return
    }
    // Notice: buffer_at cannot apply to the inner-most non-reduction loop
    // func @add_buffer_at_axis_1(%A: memref<1024x1024xf32>, %B: memref<1024x1024xf32>, %C: memref<1024x1024xf32>)
    // {
    //     %l1 = hcl.create_loop_handle "i" : !hcl.LoopHandle
    //     %l2 = hcl.create_loop_handle "j" : !hcl.LoopHandle
    //     %s = hcl.create_stage_handle "s" : !hcl.StageHandle
    //     affine.for %i = 0 to 1024 {
    //         affine.for %j = 0 to 1024 {
    //             // B[i, j] = A[i, j] + 1
    //             %a = affine.load %A[%i, %j] : memref<1024x1024xf32>
    //             %cst = constant 1.0 : f32
    //             %sum = addf %a, %cst: f32 //register
    //             affine.store %sum, %B[%i, %j] : memref<1024x1024xf32>
    //         } { loop_name = "j" }
    //     } { loop_name = "i", stage_name = "s" }
    //     // expected-error@+1 {{Cannot buffer at the inner-most loop: axis=1 inner-most axis=1}}
    //     %buf = hcl.buffer_at(%s, %B: memref<1024x1024xf32>, %l2) -> memref<1xf32>
    //     return
    // }
}