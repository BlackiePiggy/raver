import { ChevronDown, Maximize2 } from "lucide-react";

const summaryData = [
  {
    title: "Unassigned Leads",
    update: "14 mar. 01:34 pm",
    value: "10",
    color: "bg-[#dcef8a]",
  },
  {
    title: "Valuation Seller Leads",
    update: "14 mar. 01:34 pm",
    value: "95",
    color: "bg-[#f3e5a8]",
  },
  {
    title: "Potential Seller Leads",
    update: "14 mar. 01:34 pm",
    value: "231",
    color: "bg-[#f7c4c0]",
  },
];

export function SummaryCards() {
  return (
    <div className="bg-white rounded-2xl p-5 mb-4 shadow-sm">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-[15px] font-semibold">My Summary</h3>
        <button className="flex items-center gap-1 text-[12px] text-gray-600 bg-[#f5f5f7] px-2.5 py-1 rounded-full">
          This Month
          <ChevronDown className="w-3 h-3" />
        </button>
      </div>

      <div className="grid grid-cols-3 gap-3">
        {summaryData.map((item, i) => (
          <div key={i} className={`${item.color} rounded-2xl p-3.5 relative`}>
            <div className="flex items-start justify-between mb-6">
              <div className="text-[13px] font-medium text-[#1a1a1a] leading-tight max-w-[110px]">
                {item.title}
              </div>
              <button className="w-6 h-6 bg-white/60 rounded-full flex items-center justify-center">
                <Maximize2 className="w-3 h-3 text-gray-700" />
              </button>
            </div>
            <div className="flex items-end justify-between">
              <div>
                <div className="text-[10px] text-gray-700 opacity-70">Update</div>
                <div className="text-[10px] text-gray-700 opacity-70">{item.update}</div>
              </div>
              <div className="text-[26px] font-semibold leading-none">{item.value}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
