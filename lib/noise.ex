defmodule Noise do
  @behaviour :wx_object
  require Record
  Record.defrecordp :wx, Record.extract(:wx, from_lib: "wx/include/wx.hrl")
  Record.defrecordp :wxSize, Record.extract(:wxSize, from_lib: "wx/include/wx.hrl")

  defmodule State do
    defstruct [:parent, :config, :canvas, :timer, :noise, :texture]
  end

  def start(config) do
    :wx_object.start_link __MODULE__, config, []
  end

  def init(config) do
    :wx.batch(fn() -> do_init(config) end)
  end

  def do_init(config) do
    parent = :proplists.get_value :parent, config
    opts = [
      size: :proplists.get_value(:size, config),
      style: :wx_const.wx_sunken_border,
      attribList: [
        :wx_const.wx_gl_rgba,
        :wx_const.wx_gl_doublebuffer,
        :wx_const.wx_gl_min_red, 8,
        :wx_const.wx_gl_min_green, 8,
        :wx_const.wx_gl_min_blue, 8,
        :wx_const.wx_gl_depth_size, 24, 0
      ]
    ]
    canvas = :wxGLCanvas.new parent, opts
    :wxWindow.hide parent
    :wxWindow.reparent canvas, parent
    :wxWindow.show parent
    :wxGLCanvas.setCurrent canvas

    # Set up what OpenGL needs to initialize (:parent and :noise)
    initial_state = %State{
      parent: parent,
      config: config,
      canvas: canvas,
      noise: Noise.Simplex.new_config(%{min: 0.0, max: 1.0})
    }

    # Generate a noise texture once to render on every draw
    post_gl_state = setup_gl initial_state

    {parent, %{ post_gl_state | timer: :timer.send_interval(20, self, :update) }}
  end

  def handle_event(wx(event: wxSize(size: {w, h})), state) do
    unless w == 0 or h == 0, do: resize_gl_scene w, h
    {:noreply, state}
  end

  def handle_info(:update, state) do
    {:noreply, :wx.batch(fn() -> render(state) end)}
  end

  def handle_info(:stop, state) do
    :timer.cancel state.timer
    try do
      :wxGLCanvas.destroy state.canvas
    catch
      error, reason ->
        {error, reason}
    end
    {:stop, :normal, state}
  end

  def handle_call(msg, _from, state) do
    {:reply, :ok, state}
  end

  def code_change(_, _, state) do
    {:stop, :not_yet_implemented, state}
  end

  def terminate(_reason, state) do
    try do
      :wxGLCanvas.destroy state.canvas
    catch
      error, reason ->
        {error, reason}
    end
    :timer.cancel state.timer
    :timer.sleep 300
  end

  def resize_gl_scene(width, height) do
    :gl.viewport 0, 0, width, height
    :gl.matrixMode :wx_const.gl_projection
    :gl.loadIdentity
    :glu.perspective 45.0, width / height, 0.1, 100.0
    :gl.matrixMode :wx_const.gl_modelview
    :gl.loadIdentity
  end

  def setup_gl(state) do
    {w, h} = :wxWindow.getClientSize state.parent
    resize_gl_scene w, h
    :gl.enable :wx_const.gl_texture_2d
    :gl.shadeModel :wx_const.gl_smooth
    :gl.clearColor 0.0, 0.0, 0.0, 0.0
    :gl.clearDepth 1.0
    :gl.enable :wx_const.gl_depth_test
    :gl.depthFunc :wx_const.gl_lequal
    :gl.hint :wx_const.gl_perspective_correction_hint, :wx_const.gl_nicest

    # Create OpenGL texture for the image
    [texture] = :gl.genTextures 1

    %{ state | texture: texture }
  end

  def render(state) do
    draw state
    :wxGLCanvas.swapBuffers state.canvas
    state
  end

  def draw(state) do
    use Bitwise
    generate_noise_texture_data state

    :gl.clear bor(:wx_const.gl_color_buffer_bit, :wx_const.gl_depth_buffer_bit)
    :gl.loadIdentity

    # Draw a quad where we can see it
    :gl.translatef 0.0, 0.0, -4.0
    :gl.bindTexture :wx_const.gl_texture_2d, state.texture
    :gl.begin :wx_const.gl_quads
    :gl.texCoord2f 0.0, 0.0; :gl.vertex3f -1.0, -1.0,  1.0
    :gl.texCoord2f 1.0, 0.0; :gl.vertex3f  1.0, -1.0,  1.0
    :gl.texCoord2f 1.0, 1.0; :gl.vertex3f  1.0,  1.0,  1.0
    :gl.texCoord2f 0.0, 1.0; :gl.vertex3f -1.0,  1.0,  1.0
    :gl.end

    :ok
  end

  defp generate_noise_texture_data(state) do
    {w, h} = :wxWindow.getClientSize state.parent
    width = containing_power_of_two w
    height = containing_power_of_two h

    data = for x <- 0..512, y <- 0..512 do
      noise = Noise.Simplex.get(state.noise, {x, y})
      <<round(255 * noise), round(255 * noise), round(255 * noise)>>
    end |> :erlang.list_to_binary

    :gl.bindTexture :wx_const.gl_texture_2d, state.texture
    :gl.texParameteri :wx_const.gl_texture_2d, :wx_const.gl_texture_mag_filter, :wx_const.gl_linear
    :gl.texParameteri :wx_const.gl_texture_2d, :wx_const.gl_texture_min_filter, :wx_const.gl_linear
    :gl.texImage2D :wx_const.gl_texture_2d, 0, :wx_const.gl_rgb, width, height, 0, :wx_const.gl_rgb, :wx_const.gl_unsigned_byte, data
  end

  defp containing_power_of_two(x), do: containing_power_of_two(x, 1)
  defp containing_power_of_two(x, n) when n >= x, do: n
  defp containing_power_of_two(x, n), do: containing_power_of_two(x, 2*n)
end
