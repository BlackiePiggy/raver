import {
  LayoutGrid,
  BarChart3,
  LayoutDashboard,
  ListChecks,
  Users,
  Download,
  Mail,
  Type,
  MessageSquare,
  Image as ImageIcon,
  Headphones,
  Mic,
  Settings,
  ChevronDown,
  PanelLeftClose,
  Triangle,
} from "lucide-react";

const mainMenu = [
  { icon: LayoutGrid, label: "My Activity", active: true },
  { icon: BarChart3, label: "My Stats" },
  { icon: LayoutDashboard, label: "Overview" },
];

const leadsMenu = [
  { icon: ListChecks, label: "Leads List" },
  { icon: Users, label: "Buyers List" },
  { icon: Download, label: "Import" },
];

const commsMenu = [
  { icon: Mail, label: "Emails" },
  { icon: Type, label: "Texts" },
  { icon: MessageSquare, label: "Live Chat" },
  { icon: ImageIcon, label: "Postcards" },
];

export function Sidebar() {
  return (
    <div className="w-[210px] bg-white text-[#1a1a1a] flex flex-col shrink-0 border-r border-[#ececec]">
      {/* Logo */}
      <div className="px-5 pt-5 pb-6 flex items-center gap-2">
        <Triangle className="w-5 h-5 fill-[#1a1a1a] text-[#1a1a1a]" />
        <span className="text-[15px] font-semibold">Realty Hub</span>
      </div>

      {/* Menu header */}
      <div className="px-5 mb-2 flex items-center justify-between">
        <span className="text-[15px] font-medium">Menu</span>
        <PanelLeftClose className="w-4 h-4 text-gray-500" />
      </div>

      {/* Main menu */}
      <nav className="px-3 mb-4">
        {mainMenu.map((item, i) => (
          <button
            key={i}
            className={`w-full flex items-center gap-2.5 px-3 py-2 rounded-full mb-1 text-[13px] transition-colors ${
              item.active
                ? "bg-[#0f1419] text-white"
                : "text-gray-600 hover:bg-gray-50"
            }`}
          >
            <item.icon className="w-[16px] h-[16px]" />
            <span>{item.label}</span>
          </button>
        ))}
      </nav>

      {/* Leads section */}
      <div className="px-5 mb-1.5 flex items-center justify-between">
        <span className="text-[13px] text-gray-500">Leads</span>
        <ChevronDown className="w-3.5 h-3.5 text-gray-400" />
      </div>
      <nav className="px-3 mb-4">
        {leadsMenu.map((item, i) => (
          <button
            key={i}
            className="w-full flex items-center gap-2.5 px-3 py-1.5 rounded-md text-[13px] text-gray-600 hover:bg-gray-50"
          >
            <item.icon className="w-[16px] h-[16px]" />
            <span>{item.label}</span>
          </button>
        ))}
      </nav>

      {/* Comms section */}
      <div className="px-5 mb-1.5 flex items-center justify-between">
        <span className="text-[13px] text-gray-500">Comms</span>
        <ChevronDown className="w-3.5 h-3.5 text-gray-400" />
      </div>
      <nav className="px-3 flex-1">
        {commsMenu.map((item, i) => (
          <button
            key={i}
            className="w-full flex items-center gap-2.5 px-3 py-1.5 rounded-md text-[13px] text-gray-600 hover:bg-gray-50"
          >
            <item.icon className="w-[16px] h-[16px]" />
            <span>{item.label}</span>
          </button>
        ))}
      </nav>

      {/* Bottom controls */}
      <div className="px-5 py-3 flex items-center gap-3 text-gray-500">
        <Headphones className="w-4 h-4" />
        <div className="relative">
          <Mic className="w-4 h-4" />
          <span className="absolute -top-1 -right-1 w-3.5 h-3.5 bg-green-500 rounded-full text-[8px] text-white flex items-center justify-center">3</span>
        </div>
        <Settings className="w-4 h-4 ml-auto" />
      </div>

      {/* User Profile */}
      <div className="px-4 py-3 border-t border-[#ececec] flex items-center gap-2.5">
        <div className="w-8 h-8 rounded-full overflow-hidden shrink-0">
          <img
            src="https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=80&h=80&fit=crop"
            alt="Fred"
            className="w-full h-full object-cover"
          />
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-[12px] font-medium truncate">Fred Jhonson</div>
          <div className="text-[10px] text-gray-500 truncate">fredjhonson@gmail.com</div>
        </div>
      </div>
    </div>
  );
}
