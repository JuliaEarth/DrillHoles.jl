# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

const Len{T} = Quantity{T,u"𝐋"}
const Deg{T} = Quantity{T,NoDims,typeof(u"°")}

aslen(x, u) = x * u
aslen(x::Len, _) = x

asdeg(x) = x * u"°"
asdeg(x::Deg) = x
