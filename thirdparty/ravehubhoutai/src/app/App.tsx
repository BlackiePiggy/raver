import { useMemo, useState, type ReactNode } from "react";
import {
  Activity, Bell, Bookmark, Check, ChevronDown, CircleDot, Command,
  Download, Grid2X2, Headphones, Home, Image, ListChecks, Mail, Maximize2,
  MessageSquare, Mic, MoreVertical, PanelLeftClose, Phone, RefreshCw,
  Search, Settings, Sparkles, TextCursorInput, Triangle, Users, X
} from "lucide-react";

const avatarA = "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=180&h=180&fit=crop&crop=faces";
const avatarB = "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&h=120&fit=crop&crop=faces";
const avatarC = "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120&h=120&fit=crop&crop=faces";
const avatarD = "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=120&h=120&fit=crop&crop=faces";

type Toast = { id: number; text: string };

type IconButtonProps = {
  children: ReactNode;
  className?: string;
  active?: boolean;
  onClick?: () => void;
  label?: string;
};

function IconButton({ children, className = "", active, onClick, label }: IconButtonProps) {
  return (
    <button
      aria-label={label}
      onClick={onClick}
      className={`group grid place-items-center rounded-full border border-white/50 bg-white/55 shadow-[0_10px_28px_rgba(21,34,31,.08)] transition-all duration-300 hover:-translate-y-0.5 hover:bg-white/85 hover:shadow-[0_14px_34px_rgba(0,255,214,.16)] active:scale-95 ${active ? "bg-[#11131f] text-white shadow-[0_0_24px_rgba(82,244,255,.42)]" : ""} ${className}`}
    >
      {children}
    </button>
  );
}

function Toasts({ toasts }: { toasts: Toast[] }) {
  return (
    <div className="pointer-events-none fixed right-6 top-6 z-50 space-y-2">
      {toasts.map((toast) => (
        <div key={toast.id} className="rounded-full border border-white/50 bg-white/75 px-4 py-2 text-[12px] font-bold text-[#071110] shadow-[0_18px_50px_rgba(0,0,0,.16)] backdrop-blur-xl">
          {toast.text}
        </div>
      ))}
    </div>
  );
}

function Sidebar({ collapsed, setCollapsed, mobileOpen, setMobileOpen, notify }: { collapsed: boolean; setCollapsed: (v: boolean) => void; mobileOpen: boolean; setMobileOpen: (v: boolean) => void; notify: (text: string) => void }) {
  const [activeItem, setActiveItem] = useState("My Activity");
  const [profileOpen, setProfileOpen] = useState(false);
  const [muted, setMuted] = useState(false);
  const items = [
    [Activity, "My Activity"], [CircleDot, "My Stats"], [Grid2X2, "Overview"],
  ] as const;
  const leads = [[Users, "Leads List"], [ListChecks, "Buyers List"], [Download, "Import"]] as const;
  const comms = [[Mail, "Emails"], [TextCursorInput, "Texts"], [MessageSquare, "Live Chat"], [Image, "Postcards"], [Home, "Templates"]] as const;

  const Nav = ({ data }: { data: readonly (readonly [any, string])[] }) => (
    <nav className="space-y-[7px]">
      {data.map(([I, t]) => {
        const active = activeItem === t;
        return (
          <button
            key={t}
            onClick={() => { setActiveItem(t); notify(`${t} selected`); setMobileOpen(false); }}
            className={`group flex h-[42px] w-full items-center ${collapsed ? "justify-center px-0" : "gap-4 px-[15px]"} rounded-full text-[13px] font-semibold transition-all duration-300 hover:-translate-y-0.5 ${active ? "bg-[#071110] text-white shadow-[0_0_28px_rgba(91,245,255,.34)]" : "text-[#18211f] hover:bg-white/60"}`}
          >
            <span className={`grid place-items-center ${active ? "text-white" : "rounded-full bg-white/45 text-[#121b19] group-hover:bg-white/80"} ${collapsed ? "size-9" : "size-7"}`}><I className="size-[15px]" /></span>
            {!collapsed && <span>{t}</span>}
          </button>
        );
      })}
    </nav>
  );

  const quick = [
    [Headphones, "Support"], [Mic, muted ? "Unmute" : "Voice"], [Bell, "Notifications"], [ListChecks, "Tasks"], [Settings, "Settings"],
  ] as const;

  return (
    <>
      <aside className={`fixed inset-y-0 left-0 z-30 flex h-screen shrink-0 flex-col py-[25px] backdrop-blur-xl transition-all duration-500 ease-[cubic-bezier(.22,1,.36,1)] md:backdrop-blur-none md:relative ${collapsed ? "w-[86px] px-[13px]" : "w-[232px] px-[18px]"} ${mobileOpen ? "translate-x-0" : "-translate-x-full md:translate-x-0"}`}>
        <div className={`mb-[38px] flex items-center ${collapsed ? "justify-center" : "gap-3"}`}>
          <Triangle className="size-[24px] fill-[#071110] text-[#071110] drop-shadow-[0_0_10px_rgba(74,255,230,.55)]" />
          {!collapsed && <b className="text-[18px] tracking-[-.03em]">Realty Hub</b>}
        </div>

        <div className={`mb-[24px] flex shrink-0 items-center ${collapsed ? "justify-center" : "justify-between px-1"}`}>
          <span className={`${collapsed ? "hidden" : "block"} text-[18px] font-bold tracking-[-.03em]`}>Menu</span>
          <button onClick={() => setCollapsed(!collapsed)} className="grid size-8 place-items-center rounded-full transition hover:bg-white/60 active:scale-95">
            <PanelLeftClose className={`size-4 transition-transform duration-500 ${collapsed ? "rotate-180" : ""}`} />
          </button>
        </div>

        <div className="relative min-h-0 flex-1">
          <div className="absolute inset-0 overflow-y-auto px-1 py-2 scrollbar-thin scrollbar-track-transparent scrollbar-thumb-white/30">
            <div className="space-y-0">
              <Nav data={items} />
              {!collapsed && <div className="mb-3 mt-[32px] flex items-center justify-between px-1 text-[13px] font-bold"><span>Leads</span><ChevronDown className="size-4" /></div>}
              <Nav data={leads} />
              {!collapsed && <div className="mb-3 mt-[26px] flex items-center justify-between px-1 text-[13px] font-bold"><span>Comms</span><ChevronDown className="size-4" /></div>}
              <Nav data={comms} />
            </div>
          </div>
        </div>

        <div className={`mt-4 shrink-0 rounded-[24px] border border-white/55 bg-white/58 p-3 shadow-[0_24px_60px_rgba(0,0,0,.12),0_0_44px_rgba(117,255,220,.18)] ring-1 ring-white/50 backdrop-blur-2xl transition-all duration-500 ${profileOpen ? "translate-y-[-4px]" : ""}`}>
          <div className={`mb-3 flex items-center ${collapsed ? "justify-center" : "justify-between"}`}>
            {quick.slice(0, collapsed ? 1 : 5).map(([I, label], i) => (
              <button
                key={label}
                onClick={() => {
                  if (label === "Voice" || label === "Unmute") setMuted(!muted);
                  notify(label === "Voice" ? "Voice channel ready" : label);
                }}
                className={`relative grid size-9 place-items-center rounded-full bg-white/60 transition hover:-translate-y-0.5 hover:bg-white hover:shadow-[0_0_20px_rgba(110,255,234,.35)] active:scale-95 ${muted && i === 1 ? "text-rose-500" : ""}`}
              >
                <I className="size-[15px]" />
                {i === 2 && <em className="absolute -right-0.5 -top-0.5 size-4 rounded-full bg-[#25bb72] text-center text-[9px] not-italic leading-4 text-white shadow-[0_0_12px_rgba(37,187,114,.7)]">3</em>}
              </button>
            ))}
          </div>

          <button onClick={() => setProfileOpen(!profileOpen)} className={`flex w-full items-center ${collapsed ? "justify-center" : "gap-3"}`}>
            <span className="relative shrink-0">
              <img src={avatarA} className="size-10 rounded-full object-cover ring-2 ring-white" />
              <span className="absolute -right-0.5 bottom-0 size-3 rounded-full border-2 border-white bg-[#29d982]" />
            </span>
            {!collapsed && (
              <>
                <div className="min-w-0 flex-1 text-left">
                  <p className="truncate text-[13px] font-extrabold">Fred Jhonson</p>
                  <p className="truncate text-[10px] text-black/45">jhonsonfred@gmail.com</p>
                </div>
                <MoreVertical className={`size-4 transition-transform ${profileOpen ? "rotate-90" : ""}`} />
              </>
            )}
          </button>

          {!collapsed && profileOpen && (
            <div className="mt-3 rounded-[18px] bg-[#071110]/90 p-3 text-white shadow-[0_0_28px_rgba(99,255,232,.24)]">
              <div className="mb-2 flex items-center gap-2 text-[11px]"><Sparkles className="size-3.5 text-[#7dffe8]" /> Premium agent mode</div>
              <div className="grid grid-cols-2 gap-2 text-[10px] text-white/70">
                <button onClick={() => notify("Profile opened")} className="rounded-full bg-white/10 px-3 py-2 transition hover:bg-white/20">Profile</button>
                <button onClick={() => notify("Signed out demo")} className="rounded-full bg-white/10 px-3 py-2 transition hover:bg-white/20">Sign out</button>
              </div>
            </div>
          )}
        </div>
      </aside>
      {mobileOpen && <div onClick={() => setMobileOpen(false)} className="fixed inset-0 z-20 bg-black/20 md:hidden" />}
    </>
  );
}

function Topbar({ setMobileOpen, notify }: { setMobileOpen: (v: boolean) => void; notify: (text: string) => void }) {
  const [query, setQuery] = useState("");
  const [integrated, setIntegrated] = useState(false);
  return (
    <div className="flex h-[72px] shrink-0 items-center gap-3 pr-3 pt-[18px] md:gap-6 md:pr-[26px]">
      <button onClick={() => setMobileOpen(true)} className="ml-3 grid size-10 place-items-center rounded-full bg-white/60 transition hover:bg-white/80 active:scale-95 md:hidden">
        <PanelLeftClose className="size-4 rotate-180" />
      </button>
      <label className="mx-auto flex h-[42px] w-full max-w-[350px] items-center rounded-full border border-white/50 bg-white/42 px-3 shadow-[0_10px_34px_rgba(42,56,52,.05),0_0_32px_rgba(158,89,255,.10)] backdrop-blur-xl transition-all duration-300 focus-within:max-w-[410px] focus-within:bg-white/78 focus-within:shadow-[0_0_38px_rgba(93,255,236,.32)] md:px-4">
        <Search className="mr-2 size-4 shrink-0 md:mr-3" />
        <input value={query} onChange={(e) => setQuery(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter") notify(query ? `Searching ${query}` : "Type something to search"); }} className="min-w-0 flex-1 bg-transparent text-[12px] outline-none placeholder:text-black/40" placeholder="Search" />
        {query ? <button onClick={() => setQuery("")}><X className="size-4" /></button> : <Command className="size-4 max-md:hidden" />}
        <button onClick={() => notify("Voice search activated")} className="ml-2 md:ml-4"><Mic className="size-4" /></button>
      </label>
      <button onClick={() => { setIntegrated(!integrated); notify(integrated ? "Integration disconnected" : "Integration connected"); }} className={`hidden h-[42px] items-center gap-2 rounded-full px-5 text-[12px] font-bold shadow-sm transition-all hover:-translate-y-0.5 active:scale-95 md:ml-auto md:flex ${integrated ? "bg-[#071110] text-white shadow-[0_0_26px_rgba(92,255,230,.38)]" : "bg-white/50"}`}>
        {integrated ? <Check className="size-3.5" /> : <Sparkles className="size-3.5" />} Integration
      </button>
      <div className="hidden items-center -space-x-2 md:flex">
        {[["B2B", "bg-[#1d9cff]"], ["⌘", "bg-[#26122e]"], ["M", "bg-white text-red-500"]].map(([text, cls]) => (
          <button key={text} onClick={() => notify(`${text} account opened`)} className={`grid size-[42px] place-items-center rounded-full text-[11px] font-bold text-white ring-2 ring-white transition hover:-translate-y-1 hover:z-10 ${cls}`}>{text}</button>
        ))}
      </div>
    </div>
  );
}

function Profile({ notify }: { notify: (text: string) => void }) {
  const [saved, setSaved] = useState(false);
  const [expanded, setExpanded] = useState(false);
  return (
    <section className={`rounded-[28px] border border-white/40 bg-white/52 p-4 shadow-[0_28px_80px_rgba(39,57,52,.10),0_0_60px_rgba(115,255,230,.12)] backdrop-blur-xl transition-all duration-500 md:p-5 ${expanded ? "scale-[1.015] bg-white/64" : ""}`}>
      <div className="flex flex-col gap-4 md:flex-row md:gap-0">
        <img src={avatarA} className="mx-auto h-[120px] w-full max-w-[140px] rounded-[20px] object-cover object-top shadow-[0_20px_40px_rgba(0,0,0,.14)] md:mx-0 md:h-[146px] md:w-[170px]" />
        <div className="flex-1 text-center md:px-6 md:pt-2 md:text-left">
          <h2 className="text-[17px] font-extrabold">Fred Jhonson</h2>
          <p className="text-[12px] text-black/45">Agent · 186 days on the platform</p>
          <div className="mt-4 grid grid-cols-1 gap-y-3 text-[13px] font-semibold md:mt-7 md:grid-cols-2 md:gap-y-5">
            <button onClick={() => notify("Calling Fred Jhonson")} className="transition hover:text-[#0cb6c9] md:text-left">☎ &nbsp;+1-202-555-0167</button>
            <button onClick={() => notify("Email copied")} className="transition hover:text-[#0cb6c9] md:text-left">✉ &nbsp;jhonsonfred@gmail.com</button>
            <span>⌖ &nbsp;Los Angeles</span><span>▣ &nbsp;Horizon Realty Group</span>
          </div>
        </div>
        <div className="flex justify-center gap-2 md:block">
          <IconButton label="Save profile" active={saved} onClick={() => { setSaved(!saved); notify(saved ? "Profile removed from saved" : "Profile saved"); }} className="size-11"><Bookmark className={`size-4 ${saved ? "fill-current" : ""}`} /></IconButton>
          <IconButton label="Expand profile" active={expanded} onClick={() => { setExpanded(!expanded); notify(expanded ? "Profile collapsed" : "Profile expanded"); }} className="size-11"><Maximize2 className="size-4" /></IconButton>
        </div>
      </div>
      <div className="mt-4 grid grid-cols-1 gap-2 md:grid-cols-3 md:gap-1"><Stat label="Total Listings" value="1203" color="bg-[#ff8cb8]"/><Stat label="Properties sold" value="912" color="bg-[#54fff0]"/><Stat label="Properties rent" value="320" color="bg-[#d8ff72]"/></div>
    </section>
  );
}

function Stat(p:{label:string;value:string;color:string}){return <button className="text-left transition hover:-translate-y-0.5"><p className="text-[12px] text-black/45">{p.label}</p><b className="mt-1 block text-[19px]">{p.value}</b><div className={`mt-4 h-1 rounded-full ${p.color} shadow-[0_0_14px_currentColor]`}/></button>}

function Header({ title, notify }: { title: string; notify: (text: string) => void }) {
  const [range, setRange] = useState("This Month");
  const [spin, setSpin] = useState(false);
  return (
    <div className="mb-4 flex items-center justify-between">
      <h3 className="text-[18px] font-extrabold tracking-[-.03em]">{title}</h3>
      <div className="flex gap-2">
        <button onClick={() => { const next = range === "This Month" ? "This Week" : "This Month"; setRange(next); notify(next); }} className="h-10 rounded-full border border-white/50 bg-white/45 px-5 text-[12px] font-bold transition hover:bg-white/80 active:scale-95">{range} <ChevronDown className="ml-2 inline size-3"/></button>
        <IconButton label="Refresh" onClick={() => { setSpin(true); notify(`${title} refreshed`); setTimeout(() => setSpin(false), 700); }} className="size-10"><RefreshCw className={`size-4 ${spin ? "animate-spin" : ""}`}/></IconButton>
      </div>
    </div>
  );
}

function Summary({ notify }: { notify: (text: string) => void }) {
  const cards = [['Unassigned\nLeads','#d9ff78','23'],['Valuation\nSeller Leads','#65f1e7','96'],['Potential Seller\nLeads','#ff9fb9','231']];
  const [open, setOpen] = useState<string | null>(null);
  return (
    <section className="rounded-[28px] border border-white/40 bg-white/50 p-4 shadow-[0_28px_80px_rgba(39,57,52,.10),0_0_70px_rgba(153,95,255,.10)] backdrop-blur-xl md:p-5">
      <Header title="My Summary" notify={notify}/>
      <div className="grid grid-cols-1 gap-3 md:grid-cols-3 md:gap-4">
        {cards.map(([t,b,n]) => (
          <button key={t} onClick={() => { setOpen(open === t ? null : t); notify(`${t.replace("\n", " ")} opened`); }} className={`relative h-[122px] rounded-[22px] p-4 text-left transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_0_34px_rgba(91,255,236,.26)] ${open === t ? "scale-[1.03]" : ""}`} style={{background:b}}>
            <p className="whitespace-pre-line text-[13px] font-extrabold leading-[1.05]">{t}</p>
            <span className="absolute right-4 top-4 grid size-9 place-items-center rounded-full bg-white/25"><Maximize2 className="size-3.5"/></span>
            <p className="absolute bottom-5 left-4 text-[10px] text-black/55">Update<br/>14 mar. 01:34 pm</p>
            <b className="absolute bottom-5 right-5 grid size-10 place-items-center rounded-full bg-black/5 text-[13px]">{n}</b>
          </button>
        ))}
      </div>
    </section>
  );
}

function Objects({ notify }: { notify: (text: string) => void }) {
  return <section className="rounded-[28px] border border-white/40 bg-white/50 p-4 shadow-[0_28px_80px_rgba(39,57,52,.10),0_0_70px_rgba(80,255,235,.10)] backdrop-blur-xl md:p-5"><Header title="New Objects (3)" notify={notify}/><div className="grid grid-cols-1 gap-3 md:grid-cols-2 md:gap-4"><House img="https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?w=520&h=360&fit=crop" tag="Rented" notify={notify}/><House img="https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=520&h=360&fit=crop" tag="Sale" red notify={notify}/></div></section>;
}
function House({img,tag,red,notify}:{img:string;tag:string;red?:boolean;notify:(text:string)=>void}){const [zoom,setZoom]=useState(false);return <button onClick={()=>{setZoom(!zoom);notify(`${tag} object ${zoom?"closed":"preview"}`)}} className={`relative h-[178px] overflow-hidden rounded-[22px] text-left transition-all duration-500 hover:-translate-y-1 ${zoom?"scale-[1.03] shadow-[0_0_42px_rgba(95,255,235,.32)]":""}`}><img src={img} className={`size-full object-cover transition duration-700 ${zoom?"scale-110":"hover:scale-105"}`}/><span className={`absolute left-4 top-4 rounded-full px-3 py-1 text-[11px] font-bold text-white ${red?'bg-[#ff4f75]':'bg-[#31cf9d]'}`}>{tag}</span><span className="absolute right-4 top-4 grid size-11 place-items-center rounded-full bg-white/80"><Maximize2 className="size-4"/></span></button>}

function LiveFeed({ notify }: { notify: (text: string) => void }) {
  const rows = [[avatarC,'Logan Davidson','Follow up next','Agent','Created'],[avatarB,'Megan Pearce','First customer call','Lead','Was Assigned'],[avatarA,'Mason Reynolds','First customer call','Lead','Add Search']];
  const [refreshing, setRefreshing] = useState(false);
  const [selected, setSelected] = useState("");
  return (
    <div className="w-full">
      <div className="mb-5 flex items-center justify-between px-3"><b className="text-[16px]">Now online <span className="font-normal">(3)</span></b><div className="flex -space-x-2">{[avatarD,avatarB,avatarC].map((a, i)=><button key={a} onClick={() => notify(`Online user ${i + 1}`)} className="transition hover:-translate-y-1 hover:z-10"><img src={a} className="size-10 rounded-full object-cover ring-2 ring-white"/></button>)}</div></div>
      <section className="rounded-[28px] border border-white/40 bg-transparent p-4 shadow-[0_28px_80px_rgba(39,57,52,.10),0_0_70px_rgba(135,88,255,.12)] backdrop-blur-xl">
        <div className="mb-5 flex items-center justify-between"><h3 className="text-[18px] font-extrabold">Live Feed</h3><IconButton onClick={() => { setRefreshing(true); notify("Live Feed refreshed"); setTimeout(() => setRefreshing(false), 700); }} className="size-10"><RefreshCw className={`size-4 ${refreshing ? "animate-spin" : ""}`}/></IconButton></div>
        <div className="grid grid-cols-[42px_1fr] gap-3"><Timeline/><div className="space-y-4">
          <button onClick={() => { setSelected(selected === "property" ? "" : "property"); notify("Property viewed"); }} className={`w-full overflow-hidden rounded-[22px] bg-transparent text-left shadow-sm transition-all hover:-translate-y-1 ${selected === "property" ? "shadow-[0_0_34px_rgba(91,255,236,.28)]" : ""}`}><div className="relative h-[124px]"><img src="https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=400&h=260&fit=crop" className="size-full object-cover"/><span className="absolute left-3 top-3 rounded-full bg-[#ff4f75] px-3 py-1 text-[10px] font-bold text-white">$1.80</span></div><div className="p-3"><b className="text-[13px]">Single Family Residential</b><p className="text-[10px] text-black/45">305 Pomona Ave, Coronado, CA, 92118</p><div className="mt-3 flex justify-between"><span className="rounded-full bg-transparent px-3 py-2 text-[10px] shadow-sm">Property Viewed</span><div className="flex -space-x-2">{[avatarC,avatarB].map(a=><img key={a} src={a} className="size-7 rounded-full ring-2 ring-white"/>)}</div></div></div></button>
          {rows.map((r) => <button key={r[1]} onClick={() => { setSelected(String(r[1])); notify(`${r[1]} opened`); }} className={`w-full rounded-[20px] bg-transparent p-3 text-left shadow-sm transition-all hover:-translate-y-1 hover:shadow-[0_0_28px_rgba(91,255,236,.20)] ${selected === r[1] ? "ring-2 ring-[#74ffee]" : ""}`}><div className="flex items-center gap-3"><img src={r[0]} className="size-10 rounded-full object-cover"/><div className="min-w-0 flex-1"><b className="text-[13px]">{r[1]}</b><p className="text-[10px] text-black/45">{r[2]}</p></div><span onClick={(e)=>{e.stopPropagation();notify(`Calling ${r[1]}`)}} className="grid size-9 place-items-center rounded-full bg-transparent shadow-sm"><Phone className="size-3.5"/></span><span className="grid size-9 place-items-center rounded-full bg-transparent shadow-sm"><Maximize2 className="size-3.5"/></span></div><div className="mt-3 flex justify-between"><span className="rounded-full bg-transparent px-3 py-1.5 text-[10px]">{r[3]}</span><span className="rounded-full bg-transparent px-3 py-1.5 text-[10px]">{r[4]}</span></div></button>)}
        </div></div>
      </section>
    </div>
  );
}
function Timeline(){return <div className="space-y-[44px] pt-3 text-center text-[10px] font-bold text-black/70">{['Tu. 23.03\n1:24 pm','Tu. 23.03\n1:23 pm','Tu. 23.03\n1:21 pm','Tu. 23.03\n1:19 pm'].map((t,i)=><div key={i}><span className="mx-auto mb-3 grid size-9 place-items-center rounded-full bg-transparent shadow-[0_0_18px_rgba(87,255,232,.22)]"><Mail className="size-4"/></span><p className="whitespace-pre-line">{t}</p></div>)}</div>}

export default function App() {
  const [collapsed,setCollapsed]=useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const notify = (text: string) => {
    const id = Date.now();
    setToasts((current) => [...current, { id, text }].slice(-3));
    window.setTimeout(() => setToasts((current) => current.filter((toast) => toast.id !== id)), 1600);
  };
  const orbs = useMemo(() => Array.from({ length: 8 }, (_, i) => i), []);
  return (
    <main className="relative size-full overflow-hidden bg-[radial-gradient(circle_at_18%_18%,rgba(255,78,206,.30),transparent_25%),radial-gradient(circle_at_42%_34%,rgba(100,255,229,.38),transparent_30%),radial-gradient(circle_at_82%_18%,rgba(117,92,255,.32),transparent_25%),radial-gradient(circle_at_76%_76%,rgba(207,255,95,.26),transparent_28%),linear-gradient(126deg,#fbf7ef_0%,#eafbf6_43%,#eef0ff_74%,#fbf1ff_100%)] font-['Inter',sans-serif] text-[#071110]">
      <div className="pointer-events-none absolute inset-0 opacity-55 [background-image:linear-gradient(rgba(255,255,255,.36)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,.28)_1px,transparent_1px)] [background-size:42px_42px]" />
      {orbs.map((i) => <div key={i} className={`pointer-events-none absolute size-28 rounded-full blur-3xl ${i%3===0?'bg-fuchsia-300/25':i%3===1?'bg-cyan-300/30':'bg-lime-200/25'}`} style={{left:`${8+i*12}%`, top:`${(i*17)%88}%`}} />)}
      <Toasts toasts={toasts} />
      <div className="relative flex h-full">
        <Sidebar collapsed={collapsed} setCollapsed={setCollapsed} mobileOpen={mobileOpen} setMobileOpen={setMobileOpen} notify={notify}/>
        <div className="flex min-w-0 flex-1 flex-col overflow-hidden">
          <Topbar setMobileOpen={setMobileOpen} notify={notify}/>
          <div className="min-h-0 flex-1 overflow-hidden">
            <div className="h-full overflow-y-auto px-4 pb-8 pt-6 scrollbar-thin scrollbar-track-transparent scrollbar-thumb-white/30 md:px-6">
              <div className="flex flex-col gap-6 md:flex-row md:gap-6">
                <section className="min-w-0 flex-1">
                  <h1 className="mb-6 text-[28px] font-extrabold tracking-[-.06em] drop-shadow-[0_0_24px_rgba(116,255,236,.32)] md:text-[38px]">My Activity</h1>
                  <div className="space-y-4">
                    <Profile notify={notify}/>
                    <Summary notify={notify}/>
                    <Objects notify={notify}/>
                  </div>
                </section>
                <section className="w-full shrink-0 md:w-[330px]">
                  <LiveFeed notify={notify}/>
                </section>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  );
}
