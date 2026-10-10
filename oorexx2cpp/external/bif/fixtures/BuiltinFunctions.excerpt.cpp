/* The following definitions are verbatim, isolated excerpts of upstream
   ooRexx BuiltinFunctions.cpp, with the source block boundaries preserved.
   Upstream license: Common Public License v1.0, ooRexx project.
   GitHub blob: 05ea58114e9e5b59a1cceebf8dd418b78058d342 */
BUILTIN(CENTER)
{
    const size_t CENTER_Min = 2;
    const size_t CENTER_Max = 3;
    const size_t CENTER_string = 1;
    const size_t CENTER_length = 2;
    const size_t CENTER_pad =    3;

    fix_args(CENTER);

    RexxString *string = required_string(CENTER, string);
    RexxInteger *length = required_integer(CENTER, length);
    RexxString *pad = optional_pad(CENTER, pad);

    return string->center(length, pad);
}

BUILTIN(REVERSE)
{
    const size_t REVERSE_Min = 1;
    const size_t REVERSE_Max = 1;
    const size_t REVERSE_string = 1;

    fix_args(REVERSE);

    RexxString *string = required_string(REVERSE, string);

    return string->reverse();
}

BUILTIN(WORDS)
{
    const size_t WORDS_Min = 1;
    const size_t WORDS_Max = 1;
    const size_t WORDS_string = 1;

    fix_args(WORDS);

    RexxString *string = required_string(WORDS, string);

    return string->words();
}

BUILTIN(TIME)
{
    const size_t TIME_Min = 0;
    const size_t TIME_Max = 3;
    const size_t TIME_option =  1;
    const size_t TIME_intime =  2;
    const size_t TIME_option2 = 3;

    fix_args(TIME);

    RexxString *option = optional_string(TIME, option);
    RexxString *intime = optional_string(TIME, intime);
    RexxString *option2 = optional_string(TIME, option2);

    // get the current activation time and a copy for the default input
    RexxDateTime current = context->getTime();
    RexxDateTime timestamp = current;

    int style = 'N';                     // get the default style

    // do we have a style option specified?  Validate, and retrieve
    if (option != OREF_NULL)
    {
        // null strings not allowed as an option character
        if (option->getLength() == 0)
        {
            reportException(Error_Incorrect_call_list, "TIME", IntegerOne, "CEFHLMNORST", option);
        }
        // we only use the first character
        style = Utilities::toUpper(option->getChar(0));
    }

    // now repeat with the input style
    int style2 = 'N';

    // has the input style been specified?
    if (option2 != OREF_NULL)
    {
        // the second option requires an input date
        if (intime == OREF_NULL)
        {
            reportException(Error_Incorrect_call_noarg, "TIME", IntegerTwo);
        }
        // again, must be at least one character, of which we only use the first
        if (option2->getLength() == 0)
        {
            reportException(Error_Incorrect_call_list, "TIME", IntegerThree, "CFHLMNOST", option2);
        }
        style2 = Utilities::toUpper(option2->getChar(0));
    }

    // we have an input time, so we need to parse this
    if (intime != OREF_NULL)
    {
        // the input timestamp is not valid with the elapsed time options
        if (style == 'R' || style == 'E')
        {
            reportException(Error_Incorrect_call_invalid_conversion, "TIME", new_string((char *)&style, 1));
        }
        bool valid = true;                 // assume this is a good timestamp
        timestamp.clear();                 // clear everything out
        // everything is done using the current timezone offset
        timestamp.setTimeZoneOffset(current.getTimeZoneOffset());

        switch (style2)
        {
            // 'N'ormal default style, 01:23:45 format (24 hour)
            case 'N':
                valid = timestamp.parseNormalTime(intime->getStringData());
                break;

            // 'C'ivil time, 1:23pm format (12-hour, no zero)
            case 'C':
                valid = timestamp.parseCivilTime(intime->getStringData());
                break;

            // 'L'ong time, full 24-hour, plus fractional
            case 'L':
                valid = timestamp.parseLongTime(intime->getStringData());
                break;

            // 'H'our format...
            case 'H':
            {
                wholenumber_t i;
                valid = intime->numberValue(i) && timestamp.setHours(i);
                break;
            }

            case 'S':                        /* 'S'econds format                  */
            {
                wholenumber_t i;
                valid = intime->numberValue(i) && timestamp.setSeconds(i);
                break;
            }

            case 'M':                        /* 'M'inutes format                  */
            {
                wholenumber_t i;
                valid = intime->numberValue(i) && timestamp.setMinutes(i);
                break;
            }

            case 'F':                        /* 'F'ull datetime stamp            */
            {
                int64_t basetime;
                valid = Numerics::objectToInt64(intime, basetime) && timestamp.setBaseTime(basetime);
                break;
            }

            case 'T':                        /* 'T'icks datetime stamp            */
            {
                int64_t basetime;
                valid = Numerics::objectToInt64(intime, basetime) && timestamp.setUnixTime(basetime);
                break;
            }

            case 'O':                          // 'O'ffset.  microseconds offset from UTC
            {
                // everything comes from the current time stamp, but we will adjust to the new offset
                timestamp = current;                 // and by default we work off of that time
                int64_t i;
                valid = Numerics::objectToInt64(intime, i) && timestamp.adjustTimeZone(i);
                break;
            }

            // an invalid input style
            default:
                reportException(Error_Incorrect_call_list, "TIME", IntegerThree, "CFHLMNOST", new_string((char)style2));
                break;
        }
        if (!valid)
        {
            reportException(Error_Incorrect_call_format_invalid, "TIME", intime, new_string((char *)&style2, 1));
        }
    }

    // our working output buffer
    char work[64];

    // now output styles
    switch (style)
    {
        case 'E':                         // 'E'lapsed time
        case 'R':                         // 'R'eset elapsed time
        {
            // get the elapsed time from the context
            int64_t startTime = context->getElapsed();
            // substract the time values
            int64_t threshold = current.getUTCBaseTime() - startTime;
            // a negative value always returns zero and we reset
            if (threshold < 0)
            {
                strcpy(work, "0");
                context->resetElapsed();
            }
            // zero is always exactly zero
            else if (threshold == 0)
            {
                strcpy(work, "0");
            }
            else
            {
                // format as a long time
                snprintf(work, sizeof(work), "%d.%06d", (int)(threshold / (int64_t)MICROSECONDS), (int)(threshold % (int64_t)MICROSECONDS));
            }

            // if this is a reset call, then we reset the timer also
            if (style == 'R')
            {
                context->resetElapsed();
            }
            break;
        }

        case 'C':                         // 'C'ivil time
            timestamp.formatCivilTime(work, sizeof(work));
            break;

        case 'H':                         // 'Hours'
            // always return RexxInteger instead of String
            return new_integer(timestamp.hours);

        case 'L':                         // 'L'ong format
            timestamp.formatLongTime(work, sizeof(work));
            break;

        case 'M':                         // 'M'inutes format
            // always return RexxInteger instead of String
            return new_integer(timestamp.hours * MINUTES_IN_HOUR + timestamp.minutes);

        case 'N':                         // 'N'ormal format...the default
            timestamp.formatNormalTime(work, sizeof(work));
            break;

        case 'S':                         // 'S'econds format...total seconds
            // always return RexxInteger instead of String
            return new_integer((timestamp.hours * MINUTES_IN_HOUR + timestamp.minutes) * SECONDS_IN_MINUTE + timestamp.seconds);

        case 'F':                          // 'F'ull
            // if possible, return RexxInteger instead of String
#ifdef __REXX64__
            return new_integer(timestamp.getBaseTime());
#else
            timestamp.formatBaseTime(work);
            break;
#endif

        case 'T':                          // 'T'icks
            // if possible, return RexxInteger instead of String
#ifdef __REXX64__
            return new_integer(timestamp.getUnixTime());
#else
            timestamp.formatUnixTime(work);
            break;
#endif

        case 'O':                          // 'O'ffset.  microseconds offset from UTC
            // if possible, return RexxInteger instead of String
#ifdef __REXX64__
            return new_integer(timestamp.timeZoneOffset);
#else
            timestamp.formatTimeZone(work);
            break;
#endif

        // unknown output format
        default:
            work[0] = style;
            reportException(Error_Incorrect_call_list, "TIME", IntegerOne, "CEFHLMNORST", new_string(work, 1));
            break;
    }

    // return as a string object
    return new_string(work);
}

/* Verbatim upstream ooRexx BuiltinFunctions.cpp excerpts from the same blob. */
BUILTIN(COPIES)
{
    const size_t COPIES_Min = 2;
    const size_t COPIES_Max = 2;
    const size_t COPIES_string = 1;
    const size_t COPIES_n =      2;

    fix_args(COPIES);

    RexxString *string = required_string(COPIES, string);
    RexxInteger *n = required_integer(COPIES, n);

    return string->copies(n);
}

BUILTIN(C2X)
{
    const size_t C2X_Min = 1;
    const size_t C2X_Max = 1;
    const size_t C2X_string =  1;

    fix_args(C2X);

    RexxString *string = required_string(C2X, string);

    return string->c2x();
}

BUILTIN(X2C)
{
    const size_t X2C_Min = 1;
    const size_t X2C_Max = 1;
    const size_t X2C_string =  1;

    fix_args(X2C);

    RexxString *string = required_string(X2C, string);

    return string->x2c();
}

BUILTIN(BITAND)
{
    const size_t BITAND_Min = 1;
    const size_t BITAND_Max = 3;
    const size_t BITAND_string1 = 1;
    const size_t BITAND_string2 = 2;
    const size_t BITAND_pad = 3;

    fix_args(BITAND);

    RexxString *string1 = required_string(BITAND, string1);
    RexxString *string2 = optional_string(BITAND, string2);
    RexxString *pad = optional_pad(BITAND, pad);

    return string1->bitAnd(string2, pad);
}

BUILTIN(BITOR)
{
    const size_t BITOR_Min = 1;
    const size_t BITOR_Max = 3;
    const size_t BITOR_string1 = 1;
    const size_t BITOR_string2 = 2;
    const size_t BITOR_pad = 3;

    fix_args(BITOR);

    RexxString *string1 = required_string(BITOR, string1);
    RexxString *string2 = optional_string(BITOR, string2);
    RexxString *pad = optional_pad(BITOR, pad);

    return string1->bitOr(string2, pad);
}

BUILTIN(BITXOR)
{
    const size_t BITXOR_Min = 1;
    const size_t BITXOR_Max = 3;
    const size_t BITXOR_string1 = 1;
    const size_t BITXOR_string2 = 2;
    const size_t BITXOR_pad = 3;

    fix_args(BITXOR);

    RexxString *string1 = required_string(BITXOR, string1);
    RexxString *string2 = optional_string(BITXOR, string2);
    RexxString *pad = optional_pad(BITXOR, pad);

    return string1->bitXor(string2, pad);
}

BUILTIN(B2X)
{
    const size_t B2X_Min = 1;
    const size_t B2X_Max = 1;
    const size_t B2X_string = 1;

    fix_args(B2X);

    RexxString *string = required_string(B2X, string);

    return string->b2x();
}

BUILTIN(X2B)
{
    const size_t X2B_Min = 1;
    const size_t X2B_Max = 1;
    const size_t X2B_string = 1;

    fix_args(X2B);

    RexxString *string = required_string(X2B, string);

    return string->x2b();
}
