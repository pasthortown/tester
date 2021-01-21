USE [MAXPOINT_V3.0]
GO
/****** Object:  StoredProcedure [config].[PREGUNTA_SUGERIDA_IAE_preguntas_sugeridas]    Script Date: 20/1/2021 21:56:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [config].[PREGUNTA_SUGERIDA_IAE_preguntas_sugeridas] 
	(@accion				INT
	,@IDCadena				INT
	,@IDPreguntaSugerida	VARCHAR(40)
	,@descripcion			VARCHAR(100)
	,@minimo				INT
	,@maximo				INT
	,@descripcionPos		VARCHAR(100)
	,@nivel					INT
	,@estado				VARCHAR(50)
	,@respuestas			VARCHAR(MAX)
	,@IDUsuario				NVARCHAR(40) = ''
    ,@idGrupoPregunta       VARCHAR(40) = '')
AS BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE @IDStatus VARCHAR(40);

	IF(@IDUsuario = '') BEGIN
		SELECT 'ERROR' AS estado,'NO SE ENVIO EL ID DE USUARIO, NO SE REALIZA LA OPERACION' AS mensaje
		RETURN
	END

	SET @IDStatus = config.fn_estado('Preguntas Sugeridas', @estado);
	SET @idGrupoPregunta = iif(@idGrupoPregunta='',NULL,@idGrupoPregunta);

	--MODIFICAR PREGUNTA SUGERIDA
	IF(@accion = 0) BEGIN
		UPDATE dbo.Pregunta_Sugerida SET pre_sug_descripcion	= @descripcion
										,psug_resp_minima		= @minimo
										,psug_resp_maxima		= @maximo
										,psug_descripcion_pos	= @descripcionPos
										,IDStatus				= @IDStatus
										,lastUser				= @IDUsuario
										,lastUpdate				= GETDATE()
                                        ,Pregunta_SugeridaID1   = @idGrupoPregunta
		WHERE IDPreguntaSugerida = @IDPreguntaSugerida;
	--INSERT PREGUNTA SUGERIDA
	
	END ELSE IF (@accion = 1) BEGIN
		IF OBJECT_ID('tempdb..#Pregunta_Sugerida') IS NOT NULL BEGIN
			DROP TABLE #Pregunta_Sugerida;
		END

		CREATE TABLE #Pregunta_Sugerida (IDPreguntaSugerida VARCHAR(40));

		INSERT INTO dbo.Pregunta_Sugerida
		        ( pre_sug_descripcion ,
		          psug_resp_minima ,
		          psug_resp_maxima ,
		          cdn_id ,
		          psug_descripcion_pos ,
		          IDStatus ,
		          nivel ,
				  lastUser,
				  lastUpdate,
                  Pregunta_SugeridaID1)
		OUTPUT INSERTED.IDPreguntaSugerida INTO #Pregunta_Sugerida
		VALUES  ( @descripcion , -- pre_sug_descripcion - char(200)
		          @minimo , -- psug_resp_minima - int
		          @maximo , -- psug_resp_maxima - int
		          @IDCadena , -- cdn_id - int
		          @descripcionPos , -- psug_descripcion_pos - varchar(100)
		          @IDStatus , -- IDStatus - uniqueidentifier
		          @nivel , 
				  @IDUsuario,
				  getdate(),
                  @idGrupoPregunta);

		-- OBTENER ID PREGUNTA SUGERIDA
		SET @IDPreguntaSugerida = (SELECT IDPreguntaSugerida FROM  #Pregunta_Sugerida);
		DROP TABLE #Pregunta_Sugerida;

	END

	--AGREGAR RESPUESTAS A PREGUNTA SUGERIDA
	EXEC config.PREGUNTA_SUGERIDA_IAE_respuestas @IDPreguntaSugerida, @respuestas, @nivel, @IDUsuario;
	
	--LISTA PREGUNTAS SUGERIDAS
	EXEC config.USP_Paginador_Preguntas_Sugeridas_Estado 0, 11, @IDCadena, '', 'activo';

END