import { Lock, Share2, Phone, Mail, MapPin, Building2 } from "lucide-react";

export function ProfileCard() {
  return (
    <div className="bg-white rounded-2xl p-5 mb-4 shadow-sm">
      <div className="flex items-start gap-5">
        <div className="w-[110px] h-[110px] rounded-2xl overflow-hidden shrink-0">
          <img
            src="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=240&h=240&fit=crop"
            alt="Fred"
            className="w-full h-full object-cover"
          />
        </div>

        <div className="flex-1 pt-1">
          <div className="flex items-start justify-between mb-3">
            <div>
              <h2 className="text-[18px] font-semibold mb-0.5">Fred Jhonson</h2>
              <div className="text-[12px] text-gray-500">
                Agent · 286 days on the platform
              </div>
            </div>
            <div className="flex gap-1.5">
              <button className="w-7 h-7 rounded-full bg-[#f5f5f7] flex items-center justify-center hover:bg-gray-200">
                <Lock className="w-3 h-3 text-gray-700" />
              </button>
              <button className="w-7 h-7 rounded-full bg-[#f5f5f7] flex items-center justify-center hover:bg-gray-200">
                <Share2 className="w-3 h-3 text-gray-700" />
              </button>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-y-2 text-[12px] text-gray-700 mb-4">
            <div className="flex items-center gap-1.5">
              <Phone className="w-3.5 h-3.5 text-gray-400" />
              +1-202-555-0167
            </div>
            <div className="flex items-center gap-1.5">
              <Mail className="w-3.5 h-3.5 text-gray-400" />
              jhonsonfred@gmail.com
            </div>
            <div className="flex items-center gap-1.5">
              <MapPin className="w-3.5 h-3.5 text-gray-400" />
              Los Angeles
            </div>
            <div className="flex items-center gap-1.5">
              <Building2 className="w-3.5 h-3.5 text-gray-400" />
              Horizon Realty Group
            </div>
          </div>

          <div className="border-t border-gray-100 pt-3 grid grid-cols-3 gap-4">
            {[
              { label: "Total Listings", value: "1203", color: "bg-[#f87171]" },
              { label: "Properties sold", value: "912", color: "bg-[#fbbf24]" },
              { label: "Properties rent", value: "320", color: "bg-[#a3e635]" },
            ].map((stat, i) => (
              <div key={i}>
                <div className="text-[11px] text-gray-500 mb-0.5">{stat.label}</div>
                <div className="text-[20px] font-semibold mb-1.5">{stat.value}</div>
                <div className={`h-[3px] rounded-full ${stat.color}`}></div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
