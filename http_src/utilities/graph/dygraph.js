import Dygraph from 'dygraphs';

import dygraphFormat from './dygraph-format.js'
import dygraphPlotters from "./dygraph-plotters.js";
import dygraphConfig from "./dygraph-config.js";
import './dygraph-extension'
import 'dygraphs/dist/dygraph.min.css';
import '../../../assets/scripts/vendors/dygraphs/canvas.js'

export {
    Dygraph,
    dygraphFormat,
    dygraphPlotters,
    dygraphConfig
};