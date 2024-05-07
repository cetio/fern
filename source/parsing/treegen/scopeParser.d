module parsing.treegen.scopeParser;
import parsing.tokenizer.tokens;
import parsing.treegen.astTypes;
import parsing.treegen.expressionParser;
import parsing.treegen.treeGenUtils;
import parsing.treegen.tokenRelationships;
import parsing.treegen.keywords;

import tern.typecons.common : Nullable, nullable;
import std.container.array;
import errors;

struct ImportStatement
{
    dchar[][] keywordExtras;
    NamedUnit namedUnit;
    NamedUnit[] importSelection; // empty for importing everything
}

struct DeclaredFunction
{
    dchar[][] precedingKeywords;
    dchar[][] suffixKeywords;
    NamedUnit name;
    AstNode returnType;
    // TODO: Args
    ScopeData functionScope;
}

struct DeclaredVariable
{
    NamedUnit name;
    AstNode type;
}

class ScopeData
{
    Nullable!ScopeData parent; // Could be the global scope

    bool isPartialModule = false;
    Nullable!NamedUnit moduleName;
    ImportStatement[] imports;

    DeclaredFunction[] declaredFunctions;
    DeclaredVariable[] declaredVariables;
    Array!AstNode instructions;

    void toString(scope void delegate(const(char)[]) sink) const
    {
        import std.conv;

        sink("ScopeData{isPartialModule = ");
        sink(isPartialModule.to!string);
        sink(", moduleName = ");
        if (moduleName == null)
            sink("null");
        else
            sink(moduleName.value.to!string);
        sink(", imports = ");
        sink(imports.to!string);
        sink(", declaredVariables = ");
        sink(declaredVariables.to!string);

        sink(", declaredFunctions = ");
        sink(declaredFunctions.to!string);
        sink(", instructions = ");
        sink(instructions.to!string);
        sink("}");
    }
}

struct LineVarietyTestResult
{
    LineVariety lineVariety;
    size_t length;
    TokenGrepResult[] tokenMatches;
}

LineVarietyTestResult getLineVarietyTestResult(
    const(VarietyTestPair[]) scopeParseMethod, Token[] tokens, size_t index)
{
    size_t temp_index = index;

    foreach (method; scopeParseMethod)
    {
        Nullable!(TokenGrepResult[]) grepResults = method.test.matchesToken(tokens, temp_index);
        if (null != grepResults)
        {
            return LineVarietyTestResult(
                method.variety, temp_index - index, grepResults.value
            );
        }
        temp_index = index;
    }

    return LineVarietyTestResult(LineVariety.SimpleExpression, -1);
}

NamedUnit[] commaSeperatedNamedUnits(Token[] tokens, ref size_t index)
{
    NamedUnit[] units;
    while (true)
    {
        NamedUnit name = tokens.genNamedUnit(index);
        if (name.names.length == 0)
            break;
        units ~= name;
        Nullable!Token mightBeACommaN = tokens.nextNonWhiteToken(index);
        if (mightBeACommaN.ptr == null)
        {
            index--;
            break;
        }
        Token mightBeAComma = mightBeACommaN;
        if (mightBeAComma.tokenVariety != TokenType.Comma)
        {
            index--;
            break;
        }
    }
    return units;
}

import std.stdio;

LineVarietyTestResult parseLine(const(VarietyTestPair[]) scopeParseMethod, Token[] tokens, ref size_t index, ScopeData parent)
{
    dchar[][] keywords = tokens.skipAndExtractKeywords(index);

    LineVarietyTestResult lineVariety = getLineVarietyTestResult(scopeParseMethod, tokens, index);
    switch (lineVariety.lineVariety)
    {
        case LineVariety.ModuleDeclaration:
            tokens.nextNonWhiteToken(index); // Skip 'module' keyword
            parent.moduleName = tokens.genNamedUnit(index);

            parent.isPartialModule = keywords.scontains(PARTIAL_KEYWORD);

            tokens.nextNonWhiteToken(index); // Skip semicolon

            break;
        case LineVariety.TotalImport:
            tokens.nextNonWhiteToken(index); // Skip 'import' keyword
            parent.imports ~= ImportStatement(
                keywords,
                tokens.genNamedUnit(index),
                []
            );
            tokens.nextNonWhiteToken(index); // Skip semicolon
            break;
        case LineVariety.SelectiveImport:
            size_t endingIndex = index + lineVariety.length;
            scope (exit)
                index = endingIndex;

            auto statement = ImportStatement(
                keywords,
                lineVariety.tokenMatches[IMPORT_PACKAGE_NAME].assertAs(TokenGrepMethod.NamedUnit)
                    .name,
                    []
            );

            statement.importSelection ~= lineVariety
                .tokenMatches[SELECTIVE_IMPORT_SELECTIONS]
                .assertAs(TokenGrepMethod.PossibleCommaSeperated)
                .commaSeperated
                .collectNamedUnits();

            parent.imports ~= statement;
            break;
        case LineVariety.DeclarationLine:
        case LineVariety.DeclarationAndAssignment:
            size_t endingIndex = index + lineVariety.length;
            scope (exit)
                index = endingIndex;

            AstNode declarationType = lineVariety.tokenMatches[DECLARATION_TYPE].assertAs(
                TokenGrepMethod.Type).type;
            NamedUnit[] declarationNames = lineVariety.tokenMatches[DECLARATION_VARS]
                .assertAs(TokenGrepMethod.PossibleCommaSeperated)
                .commaSeperated.collectNamedUnits();
            AstNode[] nameNodes;
            foreach (NamedUnit name; declarationNames)
            {
                parent.declaredVariables ~= DeclaredVariable(name, declarationType);
                AstNode nameNode = new AstNode();
                nameNode.action = AstAction.NamedUnit;
                nameNode.namedUnit = name;
                nameNodes ~= nameNode;
            }

            if (lineVariety.lineVariety == LineVariety.DeclarationLine)
                break;

            auto nodes = lineVariety.tokenMatches[DECLARATION_EXPRESSION]
                .assertAs(TokenGrepMethod.Glob)
                .tokens.expressionNodeFromTokens();

            if (nodes.length != 1)
                throw new SyntaxError(
                    "Expression node tree could not be parsed properly (Not reducable into single node)",
                    lineVariety.tokenMatches[DECLARATION_EXPRESSION].tokens[0]);
            AstNode result = nodes[0];
            AstNode assignment = new AstNode;
            assignment.action = AstAction.AssignVariable;
            assignment.assignVariableNodeData.name = nameNodes;
            assignment.assignVariableNodeData.value = result;

            parent.instructions ~= assignment;

            break;
        case LineVariety.FunctionDeclaration:
            size_t endingIndex = index + lineVariety.length;
            scope (exit)
                index = endingIndex;
            size_t temp;
            parent.declaredFunctions ~= DeclaredFunction(
                keywords,
                [],
                lineVariety.tokenMatches[FUNCTION_NAME].assertAs(TokenGrepMethod.NamedUnit)
                    .name,
                    lineVariety.tokenMatches[FUNCTION_RETURN_TYPE].assertAs(TokenGrepMethod.Type)
                    .type,
                    parseMultilineScope(
                        FUNCTION_SCOPE_PARSE,
                        lineVariety.tokenMatches[FUNCTION_SCOPE].assertAs(TokenGrepMethod.Glob)
                        .tokens,
                        temp,
                        nullable!ScopeData(parent)
                    )
            );

            // assert(0);
            break;
        case LineVariety.ReturnStatement:
            size_t endingIndex = index + lineVariety.length;
            scope (exit)
                index = endingIndex;
            auto returnNodes = expressionNodeFromTokens(
                lineVariety.tokenMatches[0].assertAs(TokenGrepMethod.Glob).tokens
            );
            if (returnNodes.length != 1)
                throw new SyntaxError("Return statement invalid", lineVariety
                        .tokenMatches[0].tokens[0]);

            AstNode returnNode = new AstNode;
            returnNode.action = AstAction.ReturnStatement;
            returnNode.nodeToReturn = returnNodes[0];
            parent.instructions ~= returnNode;
            break;
        case LineVariety.IfStatementWithScope:
        case LineVariety.IfStatementWithoutScope:
            size_t endingIndex = index + lineVariety.length;
            scope (exit)
                index = endingIndex;

            size_t temp;

            auto conditionNodes = expressionNodeFromTokens(
                lineVariety.tokenMatches[0].assertAs(TokenGrepMethod.Glob).tokens
            );
            (lineVariety.tokenMatches[0].assertAs(TokenGrepMethod.Glob).tokens).writeln;
            if (conditionNodes.length != 1)
                throw new SyntaxError(
                    "Expression node tree could not be parsed properly (Not reducable into single node within if statement condition)",
                    lineVariety.tokenMatches[0].tokens[0]);

            ConditionNodeData conditionNodeData;
            conditionNodeData.precedingKeywords = keywords;
            conditionNodeData.condition = conditionNodes[0];
            if (lineVariety.lineVariety == LineVariety.IfStatementWithScope)
            {
                conditionNodeData.isScope = true;
                conditionNodeData.conditionScope
                    = parseMultilineScope(
                        FUNCTION_SCOPE_PARSE,
                        lineVariety.tokenMatches[1].assertAs(TokenGrepMethod.Glob)
                            .tokens,
                            temp,
                            nullable!ScopeData(parent)
                    );
            }
            else
            {
                conditionNodeData.isScope = false;
                auto conditionLineNode = expressionNodeFromTokens(
                    lineVariety.tokenMatches[1].assertAs(TokenGrepMethod.Glob).tokens
                );
                if (conditionLineNode.length != 1)
                    throw new SyntaxError(
                        "Expression node tree could not be parsed properly (if without scope)",
                        lineVariety.tokenMatches[1].tokens[0]);
                conditionNodeData.conditionResultNode = conditionLineNode[0];

            }
            AstNode node = new AstNode();
            node.action = AstAction.IfStatement;
            node.conditionNodeData = conditionNodeData;
            parent.instructions ~= node;
            break;
        case LineVariety.ElseStatementWithScope:
        case LineVariety.ElseStatementWithoutScope:
            if (!parent.instructions.length || parent.instructions[$ - 1].action != AstAction
                .IfStatement)
                throw new SyntaxError(
                    "Else statement without if statement!",
                    lineVariety.tokenMatches[1].tokens[0]);
            AstNode node = new AstNode();
            node.action = AstAction.ElseStatement;
            size_t endingIndex = index + lineVariety.length;
            scope (exit)
                index = endingIndex;

            ElseNodeData elseNodeData;
            elseNodeData.precedingKeywords = keywords;
            if (lineVariety.lineVariety == LineVariety.ElseStatementWithScope)
            {
                size_t temp;
                elseNodeData.isScope = true;
                elseNodeData.elseScope
                    = parseMultilineScope(
                        FUNCTION_SCOPE_PARSE,
                        lineVariety.tokenMatches[0].assertAs(TokenGrepMethod.Glob)
                            .tokens,
                            temp,
                            nullable!ScopeData(parent)
                    );
            }
            else
            {
                elseNodeData.isScope = false;
                auto lineNode = expressionNodeFromTokens(
                    lineVariety.tokenMatches[0].assertAs(TokenGrepMethod.Glob).tokens
                );
                if (lineNode.length != 1)
                    throw new SyntaxError(
                        "Expression node tree could not be parsed properly (else without scope)",
                        lineVariety.tokenMatches[0].tokens[0]);
                elseNodeData.elseResultNode = lineNode[0];
            }
            node.elseNodeData = elseNodeData;
            parent.instructions ~= node;
            break;
        case LineVariety.SimpleExpression:
            size_t expression_end = tokens.findNearestSemiColon(index);
            if (expression_end == -1)
                throw new SyntaxError("Semicolon not found!", tokens[index]);
            auto nodes = expressionNodeFromTokens(tokens[index .. expression_end]);
            if (nodes.length != 1)
                throw new SyntaxError(
                    "Expression node tree could not be parsed properly (Not reducable into single node)", tokens[index]);
            parent.instructions ~= nodes[0];
            index = expression_end + 1;

            break;
        default:
            import std.conv;

            assert(0, "Not yet implemented: " ~ lineVariety.lineVariety.to!string);

    }
    return lineVariety;
}

ScopeData parseMultilineScope(const(VarietyTestPair[]) scopeParseMethod, Token[] tokens, ref size_t index, Nullable!ScopeData parent)
{
    ScopeData scopeData = new ScopeData;
    scopeData.parent = parent;
    while (index < tokens.length)
    {
        LineVarietyTestResult lineData = parseLine(scopeParseMethod, tokens, index, scopeData);
        Nullable!Token testToken = tokens.nextNonWhiteToken(index);
        if (testToken == null)
            break;
        index--;

    }

    return scopeData;
}

ScopeData parseMultilineScope(const(VarietyTestPair[]) scopeParseMethod, string data)
{
    import parsing.tokenizer.make_tokens;

    size_t index;
    GLOBAL_ERROR_STATE = data;
    return parseMultilineScope(
        scopeParseMethod,
        data.tokenizeText,
        index,
        nullable!ScopeData(null)
    );
}

void tree(ScopeData scopeData) => tree(scopeData, 0);
void tree(ScopeData scopeData, size_t tabCount)
{
    import std.conv;

    alias printTabs() = {
        foreach (_; 0 .. tabCount)
            write("|  ");
    };
    alias printTabsV() = { printTabs(); write("┼ "); };

    printTabsV();
    write("Scope: ");
    write("isPartialModule = ");
    writeln(scopeData.isPartialModule);
    tabCount++;

    printTabs();
    write("Variables: ");
    foreach (var; scopeData.declaredVariables)
    {
        write(var.name.to!string ~ " as " ~ var.type.to!string);
        write(", ");
    }
    write("\n");
    printTabs();
    write("Imports: ");
    foreach (imported; scopeData.imports)
    {
        write(imported.namedUnit);
        write(": (");
        foreach (selection; imported.importSelection)
        {
            selection.write;
            write(", ");
        }
        write("), ");
    }
    write("\n");
    printTabs();
    writeln("Functions: ");
    tabCount++;
    foreach (func; scopeData.declaredFunctions)
    {
        printTabs();
        write(func.precedingKeywords);
        write(" ");
        write(func.returnType);
        write(" ");
        write(func.name);
        write("\n");
        func.functionScope.tree(tabCount);
    }
    tabCount--;
    printTabs();
    writeln("AST nodes(" ~ scopeData.instructions.length.to!string ~ "):");
    foreach (AstNode node; scopeData.instructions)
    {
        node.tree(tabCount);
    }

}
