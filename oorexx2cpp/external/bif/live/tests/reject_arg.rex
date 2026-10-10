/* Never claim that the bridge routine's ARG is the invoking compiled frame's ARG. */
say bif_live('ARG')
::requires 'rxbif_live' LIBRARY
