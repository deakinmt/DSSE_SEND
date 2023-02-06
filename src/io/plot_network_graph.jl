"""
Alias for PowerModelsAnalytics.jl functionality to plot a graph of the network.
This function requires a PowerModelsDistribution network dictionary `ntw`. 
`ntw` can be both of the `MATHEMATICAL` or `ENGINEERING` type but the latter is more
intuitive to interprete.
"""
plot_send_network(ntw::Dict; kwargs...) = plot_network(ntw; kwargs...)
"""
Alias for PowerModelsAnalytics.jl functionality to plot a graph of the network.
It queries the `ENGINEERING` data model of the network before plotting.
"""
function plot_send_network() 
    eng = parse_send_ntw_eng() 
    plot_send_network(eng)
end
"""
`function quickplot_send_network`.
Uses PowerModelsAnalytics.jl functionality to plot a graph of the network, passing some
settings to generate a tidy, readable figure.
Arguments:
    - ntw:     network data dictionary
    - savefig: if `true`, a figure is saved with path `figname`
    - figname: path/name of the figure to save. Supported extensions include png and pdf.
"""
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