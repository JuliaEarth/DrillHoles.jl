# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

const Len{T} = Quantity{T,u"𝐋"}
const Deg{T} = Quantity{T,NoDims,typeof(u"°")}

aslen(x) = x * u"m"
aslen(x::Len) = x
aslen(::Quantity) = throw(ArgumentError("invalid length unit"))

asdeg(x) = x * u"°"
asdeg(x::Deg) = x
asdeg(::Quantity) = throw(ArgumentError("unit is not degrees"))

withunit(x::Number, u) = x * u
withunit(x::Quantity, u) = uconvert(u, x)
