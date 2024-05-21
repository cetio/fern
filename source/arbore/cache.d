module arbore.cache;

import fnc.symbols;
import std.stdio;

public:
void store()
{
    string[Module] caches;
    foreach (symbol; glob.symbols.byValue)
    {
        if (!symbol.evaluated)
            continue;

        if (symbol._module !in caches)
            caches[symbol._module] = null;

        if (!symbol.isAliasSeq)
            caches[symbol._module] ~= "alias "~symbol.identifier~" = "~(cast(Alias)symbol).single.identifier~";";
        else
        {
            caches[symbol._module] ~= "alias[] "~symbol.identifier~" = [";
            foreach (sym; (cast(Alias)symbol).many)
                caches[symbol._module] ~= sym.identifier~", ";
            caches[symbol._module] = caches[symbol._module][0..$-2]~"];";
        }
    }
}