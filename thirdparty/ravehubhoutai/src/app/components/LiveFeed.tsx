import { RotateCw, Bookmark, Phone, Search } from "lucide-react";

const contacts = [
  {
    id: 1,
    name: "Logan Davidson",
    note: "Follow up next",
    tag: "Agent",
    tagColor: "bg-[#f5f5f7] text-gray-700",
    status: "Created",
    statusColor: "bg-[#f5f5f7] text-gray-700",
    time: "Tu. 03/03 · 1:25 pm",
    avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80&h=80&fit=crop",
  },
  {
    id: 2,
    name: "Megan Pearce",
    note: "First customer call",
    tag: "Lead",
    tagColor: "bg-[#fce4ec] text-[#c2185b]",
    status: "Was Assigned",
    statusColor: "bg-[#f5f5f7] text-gray-700",
    time: "11:09 am",
    avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80&h=80&fit=crop",
  },
  {
    id: 3,
    name: "Mason Reynolds",
    note: "First customer call",
    tag: "Lead",
    tagColor: "bg-[#fce4ec] text-[#c2185b]",
    status: "Add Search",
    statusColor: "bg-[#f5f5f7] text-gray-700",
    time: "8:56 am",
    avatar: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=80&h=80&fit=crop",
    sub: "Coronado, Single Family Residential",
  },
];

export function LiveFeed() {
  return (
    <div className="w-[300px] bg-[#fafafa] shrink-0 flex flex-col border-l border-[#ececec]">
      {/* Header */}
      <div className="px-4 pt-4 pb-3">
        <div className="flex items-center justify-between mb-3">
          <div className="text-[12px] text-gray-500">
            Now online <span className="text-gray-900 font-medium">(3)</span>
          </div>
          <div className="flex items-center -space-x-1.5">
            <div className="w-7 h-7 rounded-full ring-2 ring-[#fafafa] overflow-hidden">
              <img src="https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=60&h=60&fit=crop" alt="" className="w-full h-full object-cover" />
            </div>
            <div className="w-7 h-7 rounded-full ring-2 ring-[#fafafa] overflow-hidden">
              <img src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=60&h=60&fit=crop" alt="" className="w-full h-full object-cover" />
            </div>
            <div className="w-7 h-7 rounded-full ring-2 ring-[#fafafa] overflow-hidden">
              <img src="https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=60&h=60&fit=crop" alt="" className="w-full h-full object-cover" />
            </div>
          </div>
        </div>
        <div className="flex items-center justify-between">
          <h3 className="text-[15px] font-semibold">Live Feed</h3>
          <button className="w-7 h-7 rounded-full bg-white border border-gray-200 flex items-center justify-center">
            <RotateCw className="w-3.5 h-3.5 text-gray-600" />
          </button>
        </div>
      </div>

      {/* Sale card */}
      <div className="px-4 mb-3">
        <div className="bg-white rounded-2xl overflow-hidden shadow-sm">
          <div className="relative h-[110px]">
            <img
              src="https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=400&h=240&fit=crop"
              alt=""
              className="w-full h-full object-cover"
            />
            <span className="absolute top-2 left-2 bg-rose-500 text-white px-2 py-0.5 rounded-full text-[10px] font-medium">
              Sale
            </span>
            <button className="absolute top-2 right-2 w-6 h-6 bg-white/90 rounded-full flex items-center justify-center">
              <Bookmark className="w-3 h-3 text-gray-700" />
            </button>
          </div>
          <div className="p-3">
            <div className="text-[13px] font-semibold mb-0.5">Single Family Residential</div>
            <div className="text-[10px] text-gray-500 mb-2">305 Pomona Ave, Coronado, CA, 11218</div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-1 text-[11px] text-gray-600">
                <div className="w-1.5 h-1.5 rounded-full bg-emerald-500"></div>
                Property Viewed
              </div>
              <div className="flex items-center -space-x-1.5">
                <div className="w-5 h-5 rounded-full ring-2 ring-white overflow-hidden">
                  <img src="https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=40&h=40&fit=crop" alt="" className="w-full h-full object-cover" />
                </div>
                <div className="w-5 h-5 rounded-full ring-2 ring-white bg-rose-500 text-white text-[8px] flex items-center justify-center">+8</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Contacts list */}
      <div className="flex-1 overflow-auto px-4 pb-4">
        <div className="space-y-3">
          {contacts.map((c) => (
            <div key={c.id} className="flex gap-2 items-start">
              <div className="flex flex-col items-center pt-1 w-12 shrink-0">
                <div className="text-[9px] text-gray-400">Tu. 03/03</div>
                <div className="text-[9px] text-gray-400">1:25 pm</div>
              </div>
              <div className="flex-1 bg-white rounded-xl p-2.5 shadow-sm">
                <div className="flex items-center gap-2 mb-1">
                  <div className="w-7 h-7 rounded-full overflow-hidden shrink-0">
                    <img src={c.avatar} alt={c.name} className="w-full h-full object-cover" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-[12px] font-semibold truncate">{c.name}</div>
                    <div className="text-[10px] text-gray-500 truncate">{c.note}</div>
                  </div>
                  <button className="w-6 h-6 rounded-full bg-[#f5f5f7] flex items-center justify-center">
                    <Phone className="w-3 h-3 text-gray-600" />
                  </button>
                </div>
                <div className="flex items-center gap-1.5 flex-wrap">
                  <span className={`${c.tagColor} px-2 py-0.5 rounded-full text-[10px]`}>{c.tag}</span>
                  <span className={`${c.statusColor} px-2 py-0.5 rounded-full text-[10px]`}>{c.status}</span>
                </div>
                {c.sub && (
                  <div className="text-[10px] text-gray-500 mt-1.5 truncate">{c.sub}</div>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Bottom search button */}
      <div className="px-4 pb-4">
        <button className="w-8 h-8 rounded-full bg-white border border-gray-200 flex items-center justify-center shadow-sm">
          <Search className="w-3.5 h-3.5 text-gray-600" />
        </button>
      </div>
    </div>
  );
}
