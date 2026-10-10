    // Test-only instrumentation of the generated, interpreter-owned package.
    // The compiled PRIVATE declarations must live inside this package but
    // must never appear in its public routine table.
    auto allRoutines = ctx->GetPackageRoutines(pkg);
    auto publicRoutines = ctx->GetPackagePublicRoutines(pkg);
    if (!allRoutines || !publicRoutines ||
        !ctx->DirectoryAt(allRoutines, "HELPERPRIVATE") ||
        !ctx->DirectoryAt(allRoutines, "HELPEREXPLICIT") ||
        ctx->DirectoryAt(publicRoutines, "HELPERPRIVATE") ||
        ctx->DirectoryAt(publicRoutines, "HELPEREXPLICIT")) {
        ctx->RaiseException1(Rexx_Error_Execution_user_defined,
                             ctx->String("native private routine visibility mismatch"));
        return;
    }
    auto privateRoutine = static_cast<RexxRoutineObject>(ctx->DirectoryAt(allRoutines, "HELPERPRIVATE"));
    auto response = ctx->CallRoutine(privateRoutine, ctx->ArrayOfTwo(ctx->String("red"), ctx->String("blue")));
    if (ctx->CheckCondition() || !response ||
        std::string(ctx->ObjectToStringValue(response)) != "red:blue") {
        ctx->RaiseException1(Rexx_Error_Execution_user_defined,
                             ctx->String("native private routine package invocation failed"));
        return;
    }
