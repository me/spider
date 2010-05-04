<%= modules[0..-2].inject(""){ |s, mod| s+= "; " if (s.length > 0); s+="module #{mod}"}+"\n" if (modules.length > 1)%><%= "\n" if (modules.length > 1) %><% tab = (modules.length > 1) ? "    " : "" 
%><%=tab%>module <%=modules[-1]%>
<%=tab%>    include Spider::App
<%=tab%>    @controller = :<%= module_name %>Controller
<%=tab%>end
<%= "\n"+modules[0..-2].inject(""){ |s, mod| s+= "; " if (s.length > 0); s+="end" if (modules.length > 1)} 
%>require 'apps/<%= app_path %>/controllers/<%= app_name %>_controller'