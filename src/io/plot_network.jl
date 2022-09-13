plot_send_network(ntw::Dict; kwargs...) = plot_network(ntw; kwargs...)
## add docs!
function quickplot_send_network(ntw::Dict; savefig::Bool=false, figname::String="send_ntw.png")
    
    if !savefig
        plot_network(ntw; node_size_limits=[15, 20],
                          edge_width_limits=[2, 3],
                          label_nodes=true,
                          fontsize=15,
                          plot_size=(600,600),
                          plot_dpi=300)
    else
        plot_network(ntw; node_size_limits=[10, 15],
                          edge_width_limits=[2, 3],
                          label_nodes=true,
                          fontsize=10,
                          plot_size=(600,600),
                          plot_dpi=300, 
                          filename=figname)
    end
end