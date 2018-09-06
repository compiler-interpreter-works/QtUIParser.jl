import Base: setindex!, getindex

export  Widget, CustomWidget,
        PushButton, CheckBox, RadioButton, Slider, ComboBox

types = [:PushButton, :CheckBox, :RadioButton]
for T in types
  @eval begin
    mutable struct $T <: Widget
        name::String
        text::String
        properties::Vector{Property}
    end
    $T(name::AbstractString, text::AbstractString = "") = $T(name, text, Property[])
  end
end

"Allows you to move a slider  between a min and max value"
mutable struct Slider <: Widget
   name::String
   orientation::Orientation
   properties::Vector{Property}
end

function Slider(name::AbstractString, orientation::Orientation = HORIZONTAL)
    Slider(name, orientation, Property[])
end

"User can chose between several choices define by `items`"
mutable struct ComboBox <: Widget
    name::String
    properties::Vector{Property}
    items::Vector{Property}
end

function ComboBox(name::AbstractString, items::Array{T} = T[]) where T <: AbstractString
    ComboBox(name, Property[], items)
end

"Typically used for custom top level widgets"
mutable struct CustomWidget <: Widget
   name::String
   class::String
   properties::Vector{Property}
   layout::Union{Layout, Nothing}
end

function CustomWidget(name::AbstractString = "Form", class::AbstractString = "QWidget")
    CustomWidget(name, class, Property[], nothing)
end

######################  Mapping Qt Names to Types ###########################

const cname_to_type_dict = Dict("QPushButton" => PushButton,
                               "QComboBox"    => ComboBox,
                               "QCheckBox"    => CheckBox,
                               "QRadioButton" => RadioButton,
                               "QSlider"      => Slider,
                               "QWidget"      => CustomWidget)

const ename_to_enum_dict = Dict("Qt::Horizontal" => HORIZONTAL,
                                "Qt::Vertical"   => VERTICAL)

const type_to_cname_dict = Dict(PushButton  => "QPushButton",
                               ComboBox     => "QComboBox",
                               CheckBox     => "QCheckBox",
                               RadioButton  => "QRadioButton",
                               Slider       => "QSlider",
                               CustomWidget => "QWidget")

########################## Index Accessors #################################

function getindex(w::Widget, key::AbstractString)
    for p in w.properties
        if p.name == key
            return p
        end
    end
    error("No property with key $key exist")
end

function setindex!(w::Widget, value, key::AbstractString)
    i = findfirst(w->w.name == key, w.properties)
    if i == nothing
        push!(w.properties, property(key, value))
    else
        w.properties[i] = property(key, value)
    end
end

##################### IO ##########################################

function show(io::IO, w::Union{PushButton, CheckBox, RadioButton}, depth::Integer = 0)
    indent = tab^depth
    print(io, indent, string(typeof(w)))

    if isempty(w.properties)
        print(io, "(\"$(w.name)\", \"$(w.text)\")")
    else
        println(io, "(")
        properties = Property[property("name", w.name),
                              property("text", w.text),
                              w.properties...]
        show(io, properties, depth + 1)
        println(io)
        print(io, indent, ")")
    end
end

function show(io::IO, w::CustomWidget, depth::Integer = 0)
    indent = tab^depth
    print(io, indent, "Widget")

    if isempty(w.properties) && w.layout == nothing
        print(io, "(\"$(w.name)\", \"$(w.class)\")")
    else
        println(io, "(")
        properties = Property[property("name", w.name),
                              property("class", w.class),
                              w.properties...]
        show(io, properties, depth + 1)
        println(io, ",")
        print_layout(io, w.layout, depth + 1)
        print(io, indent, ")")
    end
end

##################### XML #########################################
function class_name(w::Widget)
    type_to_cname_dict[typeof(w)]
end

"""
    xml(widget)
Turn a widget such as a combobox, slider or checkbox into a tree of XML nodes.
"""
function xml(w::ComboBox)
    node = widget(class_name(w), w.name)
    add_property_nodes!(node, w)
    for item in w.items
       addchild!(node, ElementNode("item"), [xml(item)])
    end
    node
end

function xml(w::Slider)
    node = widget(class_name(w), w.name)
    add_property_nodes!(node, w)
    node
end

function xml(w::Union{PushButton, CheckBox, RadioButton})
    node = widget(class_name(w), w.name)
    addchild!(node, xml(property(w.text)))
    add_property_nodes!(node, w)
    node
end

function xml(w::CustomWidget)
    node = widget(w.class, w.name)
    add_property_nodes!(node, w)
    if w.layout != nothing
        addchild!(node, xml(w.layout))
    end
    node
end

function xml(w::Widget)
    error("Must implement xml(", typeof(w), ")")
end

function uiform(name::AbstractString = "Form")
    ElementNode("ui", [AttributeNode("version", "4.0")], [ElementNode("class", name)])
end

function widget(class::AbstractString, name::AbstractString)
    ElementNode("widget", ["class"=>class, "name"=>name])
end

function combobox(name::AbstractString)
    xml(ComboBox(name))
end

function checkbox(name::AbstractString, text::AbstractString)
    xml(CheckBox(name, text))
end

function pushbutton(name::AbstractString, text::AbstractString)
    xml(PushButton(name, text))
end