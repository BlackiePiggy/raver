import { Search, Mic, Camera, Plug } from "lucide-react";
import { ProfileCard } from "./ProfileCard";
import { SummaryCards } from "./SummaryCards";
import { FestivalCards } from "./FestivalCards";

export function MainContent() {
  return (
    <div className="flex-1 overflow-auto bg-[#fafafa]">
      {/* Top bar */}
      <div className="bg-white px-6 py-2.5 flex items-center justify-between border-b border-[#ececec]">
        <div className="flex-1 max-w-md">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" />
            <input
              type="text"
              placeholder="Search"
              className="w-full bg-[#f5f5f7] rounded-full pl-9 pr-16 py-1.5 text-[13px] outline-none"
            />
            <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-2 text-gray-400">
              <Mic className="w-3.5 h-3.5" />
              <Camera className="w-3.5 h-3.5" />
            </div>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <button className="flex items-center gap-1.5 text-[12px] text-gray-600">
            <Plug className="w-3.5 h-3.5" />
            Integration
          </button>
          <div className="flex items-center -space-x-1.5">
            <div className="w-7 h-7 rounded-full ring-2 ring-white overflow-hidden">
              <img src="https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=60&h=60&fit=crop" alt="" className="w-full h-full object-cover" />
            </div>
            <div className="w-7 h-7 rounded-full ring-2 ring-white overflow-hidden">
              <img src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=60&h=60&fit=crop" alt="" className="w-full h-full object-cover" />
            </div>
            <div className="w-7 h-7 rounded-full ring-2 ring-white bg-rose-500 text-white text-[10px] flex items-center justify-center">+5</div>
          </div>
        </div>
      </div>

      {/* Heading */}
      <div className="px-6 pt-5 pb-3">
        <h1 className="text-[26px] font-semibold">My Activity</h1>
      </div>

      {/* Content */}
      <div className="px-6 pb-6">
        <ProfileCard />
        <SummaryCards />
        <FestivalCards />
      </div>
    </div>
  );
}
