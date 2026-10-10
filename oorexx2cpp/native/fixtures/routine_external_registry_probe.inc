    auto privateEntries = ctx->GetPackageRoutines(pkg);
    auto publicEntries = ctx->GetPackagePublicRoutines(pkg);
    auto sinRoutine = ctx->DirectoryAt(privateEntries, "RX_MATH_SIN");
    if (sinRoutine == NULLOBJECT ||
        ctx->DirectoryAt(publicEntries, "RX_MATH_SIN") != NULLOBJECT ||
        ctx->DirectoryAt(privateEntries, "RX_MATH_DEFAULT") == NULLOBJECT) {
        ctx->RaiseException1(Rexx_Error_Execution_user_defined,
                 ctx->String("private external routing visibility mismatch"));
        return;
    }
    auto sinResult = ctx->CallRoutine(static_cast<RexxRoutineObject>(sinRoutine),
                    ctx->ArrayOfOne(ctx->String("90")));
    if (ctx->CheckCondition()) return;
    if (sinResult == NULLOBJECT || !ctx->IsOfType(sinResult, "STRING") ||
        std::string(ctx->ObjectToStringValue(sinResult)) != "1") {
        ctx->RaiseException1(Rexx_Error_Execution_user_defined,
                 ctx->String("external sin execution differs from ooRexx"));
        return;
    }
