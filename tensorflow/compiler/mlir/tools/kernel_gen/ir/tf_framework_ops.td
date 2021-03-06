/* Copyright 2020 The TensorFlow Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

// This is the operation definition file for TF Framework ops.

#ifndef TF_FRAMEWORK_OPS
#define TF_FRAMEWORK_OPS

include "mlir/IR/OpBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def TFFramework_Dialect : Dialect {
  let name = "tf_framework";

  let summary = "Types and operations for tf_framework dialect";
  let description = [{
    This dialect contains operations and types for that correspond to
    TensorFlow C++ Framework.
  }];
  let cppNamespace = "::mlir::kernel_gen::tf_framework";
}

def TFFramework_OpKernelContextType : DialectType<TFFramework_Dialect,
    CPred<"$_self.isa<::mlir::kernel_gen::tf_framework::OpKernelContextType>()">,
          "op_kernel_construction">,
    BuildableType<"$_builder.getType<::mlir::kernel_gen::tf_framework::OpKernelContextType>()"> {
  let typeDescription = [{
    OpKernelContextType corresponds to C++ class OpKernelContext defined in
    tensorflow/core/framework/op_kernel.h
  }];
}

// Base class for TF Framework dialect ops.
class TFFramework_Op<string mnemonic, list<OpTrait> traits = []> :
    Op<TFFramework_Dialect, mnemonic, traits> {
  let verifier = "return Verify<$cppClass>(*this);";
}

//===----------------------------------------------------------------------===//
// TFAllocOp
//===----------------------------------------------------------------------===//
def TFFramework_TFAllocOp : TFFramework_Op<"alloc",
    [MemoryEffects<[MemAlloc<DefaultResource>]>]> {
  let summary = "allocation of tensors that uses TF Framework";
  let description = [{
    Allocation of tensors during kernel execution in the Compute method.

    This should be used to allocate any temporary or output memref. If
    `output_index` and `input_indices` are given, attempts to forward one of
    the input tensors to the output by calling `OpKernelContext::forward_input`.

    If the attributes are missing or the forwarding fails, calls
    `Allocator::AllocateRaw` in tensorflow/core/framework/allocator.h.
  }];

  let arguments = (ins
    TFFramework_OpKernelContextType:$ctx,
    Variadic<Index>:$dyn_sizes,
    OptionalAttr<I32ArrayAttr>:$input_indices,
    OptionalAttr<I32Attr>:$output_index
  );
  let results = (outs Res<AnyMemRef, "", [MemAlloc<DefaultResource>]>:$result);

  let builders = [
    OpBuilderDAG<(ins "MemRefType":$memref_type, "Value":$ctx),
    [{
      $_state.addOperands(ctx);
      $_state.types.push_back(memref_type);
    }]>,
    OpBuilderDAG<(ins "MemRefType":$memref_type, "Value":$ctx,
      "ValueRange":$dyn_sizes),
    [{
      build($_builder, $_state, memref_type, ctx);
      $_state.addOperands(dyn_sizes);
    }]>];

  let extraClassDeclaration = [{
    MemRefType getType() { return getResult().getType().cast<MemRefType>(); }
  }];
  let assemblyFormat = [{
    `(` $ctx (`,` $dyn_sizes^ )? `)` attr-dict `:` type($result)
  }];
}

//===----------------------------------------------------------------------===//
// TFDeallocOp
//===----------------------------------------------------------------------===//
def TFFramework_TFDeallocOp : TFFramework_Op<"dealloc",
    [MemoryEffects<[MemFree]>]> {
  let summary = "deallocation of tensors that uses TF Framework";
  let description = [{
    Deallocation of tensors during kernel execution in the Compute method.

    This should be used to deallocate any temporary memref that was allocated
    with `tf_framework.alloc`.
    Corresponds to `Allocator::DeallocateRaw` in
    tensorflow/core/framework/allocator.h.
  }];

  let arguments = (ins TFFramework_OpKernelContextType:$ctx,
                   Arg<AnyMemRef, "", [MemFree]>:$memref);
  let assemblyFormat = "`(` $ctx `,` $memref `)` attr-dict `:` type($memref)";
}

//===----------------------------------------------------------------------===//
// NullContextOp
//===----------------------------------------------------------------------===//
def TFFramework_NullContextOp : TFFramework_Op<"null_context",
    [NoSideEffect]> {
  let summary = "Creates a fake TF context that will be lowered to nullptr";
  let description = [{Needed for testing}];
  let results = (outs TFFramework_OpKernelContextType:$result);
  let assemblyFormat = "`(` `)` attr-dict `:` type($result)";
}

#endif // TF_FRAMEWORK_OPS
