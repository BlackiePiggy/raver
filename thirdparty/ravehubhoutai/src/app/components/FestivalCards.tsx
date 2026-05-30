import { ChevronDown, Maximize2 } from "lucide-react";

const properties = [
  {
    id: 1,
    image: "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=500&h=300&fit=crop",
    badge: "Rented",
    badgeColor: "bg-emerald-500",
  },
  {
    id: 2,
    image: "https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=500&h=300&fit=crop",
    badge: "Sale",
    badgeColor: "bg-rose-500",
  },
];

export function FestivalCards() {
  return (
    <div className="bg-white rounded-2xl p-5 shadow-sm">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-[15px] font-semibold">
          New Objects <span className="text-gray-400 font-normal">(3)</span>
        </h3>
        <button className="flex items-center gap-1 text-[12px] text-gray-600 bg-[#f5f5f7] px-2.5 py-1 rounded-full">
          This Month
          <ChevronDown className="w-3 h-3" />
        </button>
      </div>

      <div className="grid grid-cols-2 gap-3">
        {properties.map((p) => (
          <div key={p.id} className="relative rounded-2xl overflow-hidden h-[160px]">
            <img src={p.image} alt="" className="w-full h-full object-cover" />
            <span className={`absolute top-2.5 left-2.5 ${p.badgeColor} text-white px-2.5 py-0.5 rounded-full text-[11px] font-medium`}>
              {p.badge}
            </span>
            <button className="absolute top-2.5 right-2.5 w-6 h-6 bg-white/90 rounded-full flex items-center justify-center">
              <Maximize2 className="w-3 h-3 text-gray-700" />
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}
