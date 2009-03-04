require 'apps/<%= app_path %>/controllers/<%= app_name %>.rb'<% tab = (modules.length > 1) ? "    " : "" %><%= "\n" if (modules.length > 1) %>
<%= modules[0..-2].inject(""){ |s, mod| s+= "; " if (s.length > 0); s+="module #{mod}"}+"\n" if (modules.length > 1)%>
<%=tab%>module <%=modules[-1]%>
<%=tab%>    @description = ""
<%=tab%>    @version = 0.1
<%=tab%>    @path = File.dirname(__FILE__)
<%=tab%>    @controller = :<%= module_name %>Controller
<%=tab%>    include Spider::App
<%=tab%>end
<%= "\n"+modules[0..-2].inject(""){ |s, mod| s+= "; " if (s.length > 0); s+="end" if (modules.length > 1)} %>