using PLists

export read_ui, read_ui_string,
       findproperty, findwidget

# Qt class name to Julia type mapping
const cname_to_type_dict = Dict("QPushButton" => PushButton, 
                               "QComboBox"    => ComboBox,
                               "QCheckBox"    => CheckBox,
                               "QRadioButton" => RadioButton,
                               "QWidget"      => CustomWidget)

const ename_to_enum_dict = Dict("Qt::Horizontal" => horizontal, 
                                "Qt::Vertical"   => vertical)
#
"Looks for a child node of `n` which is a property with name `name`."
findproperty(n::Node, name::AbstractString) = locatefirst(["property"], "name", name, n)

"""
    findwidget(node, name) -> Node
Recursively search from XML DOM node `node` for a widget named `name`.
# Example

"""
function findwidget(node::Node, name::AbstractString)
    if nodename(node) == "widget" && haskey(node, "name") && node["name"] == name
       return node
    else
        for n in nodes(node)
           m = findwidget(n, name)
           if m != nothing
               return m
           end 
        end
    end
    nothing
end

function findwidget(doc::Document, name::AbstractString)
    if !hasroot(doc) return nothing end
    findwidget(root(doc), name)
end

"Convert an Qt enum string such as `Qt::Horizontal` to a Julia enum value"
function parse_enum(s::AbstractString)
    ename_to_enum_dict[s]
end

function parse_rect(n::ElementNode)
    value(key) = Meta.parse(nodecontent(locatefirst(key, n)))
    x       = value("x")
    y       = value("y")
    width   = value("width")
    height  = value("height")            
    Rect(x, y, width, height)
end

function parse_property_data(n::ElementNode)
    tag = nodename(n)
    if     "string" == tag
        nodecontent(n)
    elseif "enum" == tag
        parse_enum(nodecontent(n))
    elseif "bool" == tag
        parse(nodecontent(n))
    elseif "rect" == tag
        parse_rect(n)
    end
end


function parse_property(n::ElementNode)
    name  = n["name"]
    children = elements(n)
    if isempty(children)
        error("property node is missing data")
    end
    data_node = first(children)
    property(name, parse_property_data(data_node))
end

function parse_func_signature(s::AbstractString, T::DataType)
    m = match(r"\s*(\w+)\(([\w,\s]*)\)", s)
    if m == nothing
       @error "Was not able to parse signal or slot method '$s'" 
    else
       T(m[1], split(m[2])) 
    end    
end

function parse_connection(node::ElementNode)
    value(key) = nodecontent(locatefirst(key, n))
    
    sender     = value("sender")
    receiver   = value("receiver")
    signal_str = value("signal")
    slot_str   = value("slot")
    
    signal = parse_func_signature(signal_str, Signal)
    slot   = parse_func_signature(signal_str, Slot)
    
    Connection(sender, signal, receiver, slot)
end

function parse_connections(node::ElementNode)
    connections = elements(node)
    [parse_connection(conn) for conn in connections]    
end

function parse_layout(node::ElementNode)
    class = node["class"]
    name  = node["name"]
    
    items = Union{Layout, Widget}[]
    
    item_nodes = elements(node)
    for item_node in item_nodes
        children = elements(item_node)
        child = first(children)
        tag = nodename(child)
        if     "widget" == tag
            w = parse_widget(child)
            push!(items, w)
        elseif "layout" == tag
            l = parse_layout(child)
            push!(items, l)
        elseif "spacer" == tag
            push!(items, ) # TODO: Parse spacers properly
        else
            @error "Don't know how to parse items of type '$tag'"
        end
    end
    
    if     "QVBoxLayout" == class
        BoxLayout(name, vertical, items)
    elseif "QHBoxLayout" == class
        BoxLayout(name, horizontal, items)
    else
        @error "Missing code to handle Layout of type '$class'"
    end
end

# TODO: Implement when we know more about the structure of resources XML
function parse_resources(node::ElementNode)
    Resource[]
end

function parse_widget(node::ElementNode)
    cname = node["class"] # class name
    name  = node["name"]
    
    children = elements(node)
    
    properties = Property[]
    layout = nothing
    for child in children
        tag = nodename(child)
        if     tag == "property"
            push!(properties, parse_property(child))
        elseif tag == "layout"
            layout = parse_layout(child)
        end
    end
    # TODO: how do we deal with other widgets?
    CustomWidget(name, cname, properties, layout)
end

function read_ui_string(text::AbstractString)
    doc = parsexml(text)
    if !hasroot(doc)
        return nothing
    end
    
    ui = root(doc)
    if nodename(ui) != "ui"
        error("Expected root node to be 'ui' not '$(nodename(ui))'") 
    end
    version = ui["version"]
    children = elements(ui)
    root_widget = parse_widget(locatefirst("widget", ui))
    connections = parse_connections(locatefirst("connections", ui))
    resources   = parse_resources(locatefirst("resources", ui))
    
    Ui(root_widget, connections, version)
end

"""
Read Qt `.ui` file
"""
function read_ui(stream::IO)
    text = read(stream, String)
    read_ui_string(text)
end

function read_ui(filename::AbstractString)
    open(read_ui, filename)
end

# root = read_ui("testpanel.ui")
# xroot = rootnode("testform.ui")
