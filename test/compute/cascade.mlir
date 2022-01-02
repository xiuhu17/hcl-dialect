// RUN: hcl-opt %s | hcl-opt | FileCheck %s

module {
    func @gemm(%A: memref<1024x512xf32>, %B: memref<512x1024xf32>) -> memref<1024x1024xf32>
    {
        %C = memref.alloc() : memref<1024x1024xf32>
        affine.for %i = 0 to 1024 {
            affine.for %j = 0 to 1024 {
                affine.for %k = 0 to 512 {
                    %a = affine.load %A[%i, %k] : memref<1024x512xf32>
                    %b = affine.load %B[%k, %j] : memref<512x1024xf32>
                    %c = affine.load %C[%i, %j] : memref<1024x1024xf32>
                    %prod = mulf %a, %b : f32
                    %sum = addf %prod, %c: f32
                    affine.store %sum, %C[%i, %j] : memref<1024x1024xf32>
                } { loop_name = "k", reduction = 1 : i32}
            } { loop_name = "j" }
        } { loop_name = "i", stage_name = "s" }
        return %C : memref<1024x1024xf32>
    }
    func @matrix_multiply(%A: tensor<1024x512xf32>, %B: tensor<512x1024xf32>, %C: tensor<1024x1024xf32>)
    {
        %l1 = hcl.create_loop_handle "i" : !hcl.LoopHandle
        %l2 = hcl.create_loop_handle "j" : !hcl.LoopHandle
        %l3 = hcl.create_loop_handle "k" : !hcl.LoopHandle
        %s = hcl.create_stage_handle "s" : !hcl.StageHandle
        affine.for %i = 0 to 1024 {
            affine.for %j = 0 to 1024 {
                affine.for %k = 0 to 512 {
                    %a = tensor.extract %A[%i, %k] : tensor<1024x512xf32>
                    %b = tensor.extract %B[%k, %j] : tensor<512x1024xf32>
                    %c = tensor.extract %C[%i, %j] : tensor<1024x1024xf32>
                    %prod = mulf %a, %b : f32
                    %sum = addf %prod, %c: f32
                    tensor.insert %sum into %C[%i, %j] : tensor<1024x1024xf32>
                } { loop_name = "k" }
            } { loop_name = "j" }
        } { loop_name = "i", stage_name = "s" }
        %l4, %l5 = hcl.split (%s, %l1, 8)
        %l6, %l7, %l8, %l9 = hcl.tile (%s, %l2, %l3, 2, 4) // split & tile
        %l10, %l11 = hcl.split (%s, %l6, 16)
        return
    }
}