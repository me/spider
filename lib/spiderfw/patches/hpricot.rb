module Hpricot
    class DocType
        def output(out, opts = {})
            out <<
            if_output(opts) do
                "<!DOCTYPE #{target}" +
                (public_id ? " PUBLIC \"#{public_id}\"" : "") +
                (system_id ? " SYSTEM #{html_quote(system_id)}" : "") + ">"
            end
        end
    end

end