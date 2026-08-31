# Sidebar nav link styling for the admin back office (A1 navigation
# skeleton — docs/ADMIN_CONSOLE_PLAN.md). Kept as a tiny helper rather than
# duplicating the active/inactive class strings in every `admin/**` view.
module Admin::NavigationHelper
  def admin_nav_link_class(active)
    base = "block! whitespace-nowrap! rounded-lg! px-3! py-2! text-sm! font-medium! transition!"
    return "#{base} bg-indigo-50! text-indigo-700!" if active

    "#{base} text-slate-600! hover:bg-slate-100!"
  end
end
