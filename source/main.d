module main;

import fnc.tokenizer.tokens;
import fnc.tokenizer.make_tokens;
import tern.typecons.common : Nullable, nullable;
import fnc.treegen.scope_parser;
import fnc.treegen.relationships;

import std.stdio;

public enum GenerationFlags {
    /// `--rwx`
    /// All code is RWX instead of RX, allowing for polymorphism.
    RWX,
    /// `--nolrc`
    /// Disables linear reference counting.
    NoLRC,
    /// `--prune`
    /// Dead code is cleaned up, like useless variables or calls.
    Prune,
    /// `--reduce`
    /// Instructions are optimized for code size and reduced as much as possible.
    /// Will not prune.
    Reduce,
    /// `--vectorize`
    /// Auto vectorization, instructions are chosen based on target.
    Vectorize,
    /// `--pipelining`
    /// Optimizes the pipeline as much as possible, may reorder instructions.
    Pipelining,
    /// `--traverse-abi`
    /// Traverses instructions to heuristically determine an ABI for functions.
    TABI,
    /// `--traverse-hinting`
    /// Hinting for registers to try to prevent use of the stack or heap when possible.
    THinting,
    /// `--traverse-merging`
    /// Load and store merging.
    TMerging,
    /// `--e-pure`
    /// Fully enforces purity on an instruction level.
    EPure,
    /// `--e-const`
    /// Fully enforces constness on an instruction level.
    EConst,
    /// `--e-ref`
    /// Fully enforces refness on an instruction level.
    ERef,

    // Feature sets
    Common,
    Native, // Remaining features may be toggled, sourced from gallinule ID enums (not CR)
}

void main() {
    size_t index = 0;

    import fnc.treegen.expression_parser;
    import fnc.treegen.ast_types;
    import std.container.array;

    auto newScope = parseMultilineScope(GLOBAL_SCOPE_PARSE, "
        T add(T = int)(T a, T b){
            return => a + b;
        }
        
        int main(){
            int? x = add!int(3, 3);
        }
    ");

    newScope.tree;

}
